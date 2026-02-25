//
//  TextSceneVM.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

// TextSceneVM.swift
// AWARE — Text Message Scene Logic (pure Swift Concurrency)

import SwiftUI

@Observable
@MainActor
final class TextSceneVM {
    
    var bubbles: [ChatBubble] = []
    var choices: [ActiveChoice] = []
    var isTyping = false
    var choicesVisible = false
    var showTransitionButton = false
    
    private let scene: TextScene
    private let settings: SettingsManager
    private let onPoints: (Int) -> Void
    private let onTransition: () -> Void
    
    private var nodeIndex = 0
    private nonisolated(unsafe) var runTask: Task<Void, Never>?
    
    init(scene: TextScene,
         settings: SettingsManager,
         onPoints: @escaping (Int) -> Void,
         onTransition: @escaping () -> Void) {
        self.scene = scene
        self.settings = settings
        self.onPoints = onPoints
        self.onTransition = onTransition
    }
    
    deinit { runTask?.cancel() }
    
    // MARK: - Public
    
    func triggerTransition() {
        onTransition()
    }
    
    func start() {
        nodeIndex = 0
        bubbles = []
        choices = []
        choicesVisible = false
        isTyping = false
        driveFromCurrent()
    }
    
    func selectChoice(_ choice: ActiveChoice) {
        // Cancel existing task first
        runTask?.cancel()
        
        withAnimation(G.appear) {
            choicesVisible = false
            choices = []
            bubbles.append(ChatBubble(kind: .player, text: choice.text))
        }
        onPoints(choice.points)
        
        let currentNode = scene.nodes[nodeIndex]
        guard let option = currentNode.options?.first(where: { $0.optionId == choice.tag }) else {
            // Move to next node and continue
            nodeIndex += 1
            driveFromCurrent()
            return
        }
        
        runTask = Task {
            print("🔵 selectChoice: Starting task for choice '\(choice.text)'")
            
            // Handle branch messages if present
            if let branchMsgs = option.branchMessages, !branchMsgs.isEmpty {
                print("🔵 selectChoice: Found \(branchMsgs.count) branch messages")
                let totalChars = branchMsgs.map { $0.l(settings.language).count }.reduce(0, +)
                let delay = settings.pacing.ns(charCount: totalChars)
                isTyping = true
                try? await Task.sleep(nanoseconds: delay)
                isTyping = false
                
                for (i, msg) in branchMsgs.enumerated() {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    withAnimation(G.appear) {
                        bubbles.append(ChatBubble(kind: .npc, text: msg.l(settings.language)))
                    }
                    print("🔵 selectChoice: Displayed branch message \(i + 1)/\(branchMsgs.count)")
                }
            }
            
            // Small delay before checking what's next
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            // Move to the next node
            nodeIndex += 1
            print("🔵 selectChoice: Moved to node index \(nodeIndex) of \(scene.nodes.count)")
            
            // Check if we've reached the end
            guard nodeIndex < scene.nodes.count else {
                print("🔵 selectChoice: Reached end of nodes, showing transition button")
                showTransitionButton = true
                return
            }
            
            // Check if next node is a transition trigger
            let nextNode = scene.nodes[nodeIndex]
            print("🔵 selectChoice: Next node type='\(nextNode.type)', systemEvent='\(nextNode.systemEvent ?? "nil")'")
            if nextNode.type == "message_block", nextNode.systemEvent == "transition_to_encounter" {
                print("🔵 selectChoice: Found transition trigger, showing button")
                let wait = settings.pacing == .fast ? UInt64(100_000_000) : UInt64(800_000_000)
                try? await Task.sleep(nanoseconds: wait)
                showTransitionButton = true
                return
            }
            
            // Continue processing from the new position
            print("🔵 selectChoice: Calling continueFromCurrent()")
            await continueFromCurrent()
        }
    }
    
    // Helper to continue processing without canceling the current task
    private func continueFromCurrent() async {
        print("🟢 continueFromCurrent: Starting at node \(nodeIndex) of \(scene.nodes.count)")
        
        while nodeIndex < scene.nodes.count {
            if Task.isCancelled {
                print("🔴 continueFromCurrent: Task was cancelled at node \(nodeIndex)")
                return
            }
            
            let node = scene.nodes[nodeIndex]
            print("🟢 continueFromCurrent: Processing node \(nodeIndex), type='\(node.type)'")
            
            switch node.type {
            case "message_block":
                await emitMessageBlock(node)
                
                // Transition event
                if node.systemEvent == "transition_to_encounter" {
                    print("🟢 continueFromCurrent: Found transition event, showing button")
                    let wait = settings.pacing == .fast ? UInt64(100_000_000) : UInt64(800_000_000)
                    try? await Task.sleep(nanoseconds: wait)
                    showTransitionButton = true
                    return
                }
                
                // Add small delay before checking for choices
                try? await Task.sleep(nanoseconds: 200_000_000)
                
                // If next node is a choice, present it and wait for player
                if nodeIndex + 1 < scene.nodes.count,
                   scene.nodes[nodeIndex + 1].type == "player_choice" {
                    print("🟢 continueFromCurrent: Next node is a choice, showing choices")
                    nodeIndex += 1
                    await showChoices(scene.nodes[nodeIndex])
                    return
                }
                nodeIndex += 1
                
            case "player_choice":
                print("🟢 continueFromCurrent: Current node is a choice, showing choices")
                await showChoices(node)
                return
                
            case "system_event":
                print("🟢 continueFromCurrent: Processing system_event")
                if let lbl = node.label {
                    let text = lbl.l(settings.language)
                    try? await Task.sleep(nanoseconds: settings.pacing == .fast ? 200_000_000 : 800_000_000)
                    withAnimation(G.appear) {
                        bubbles.append(ChatBubble(kind: .system, text: text))
                    }
                    try? await Task.sleep(nanoseconds: settings.pacing == .fast ? 300_000_000 : 1_200_000_000)
                }
                nodeIndex += 1
                
            default:
                print("🟢 continueFromCurrent: Unknown node type, skipping")
                nodeIndex += 1
            }
        }
        
        print("🟢 continueFromCurrent: Reached end of nodes, showing transition button")
        showTransitionButton = true
    }
    
    // MARK: - Processing
    
    private func driveFromCurrent() {
        // Cancel any existing task first
        runTask?.cancel()
        
        runTask = Task {
            await continueFromCurrent()
        }
    }
    
    private func emitMessageBlock(_ node: TextNode) async {
        guard let messages = node.messages else { return }
        let lang = settings.language
        let isPlayer = (node.sender ?? "Andreas") == "Player"
        let kind: BubbleKind = isPlayer ? .player : .npc
        
        if !isPlayer {
            let totalChars = messages.map { $0.l(lang).count }.reduce(0, +)
            isTyping = true
            try? await Task.sleep(nanoseconds: settings.pacing.ns(charCount: totalChars))
            isTyping = false
        }
        
        for (i, msg) in messages.enumerated() {
            withAnimation(G.appear) {
                bubbles.append(ChatBubble(kind: kind, text: msg.l(lang)))
            }
            if i < messages.count - 1 {
                try? await Task.sleep(nanoseconds: isPlayer ? 150_000_000 : 400_000_000)
            }
        }
        
        // Scripted response delay (native mode only)
        if isPlayer, let delayMs = node.responseDelayMs, settings.pacing == .native {
            let capped = min(UInt64(delayMs) * 1_000_000, 8_000_000_000)
            isTyping = true
            try? await Task.sleep(nanoseconds: capped)
            isTyping = false
        }
    }
    
    private func showChoices(_ node: TextNode) async {
        guard let opts = node.options else { return }
        let lang = settings.language
        
        // Small delay to ensure UI is ready
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        choices = opts.map { ActiveChoice(text: $0.text.l(lang), points: $0.points, tag: $0.optionId) }
        withAnimation(G.soft) { choicesVisible = true }
    }
}
