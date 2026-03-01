//
//  TextSceneVM.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

import SwiftUI

@Observable
@MainActor
final class TextSceneVM {
    
    var bubbles: [ChatBubble] = []
    var choices: [ActiveChoice] = []
    var isTyping = false
    var isPlayerTyping = false  // NEW: Track player typing state
    var choicesVisible = false
    var showTransitionButton = false
    
    private let scene: TextScene
    private let settings: SettingsManager
    private let onPoints: (Int) -> Void
    private let onTransition: () -> Void
    private weak var coordinator: GameCoordinator?  // NEW: Keep reference to update save state
    
    private(set) var nodeIndex = 0  // Make readable from outside
    @ObservationIgnored
    private var runTask: Task<Void, Never>?
    
    init(scene: TextScene,
         settings: SettingsManager,
         coordinator: GameCoordinator,
         onPoints: @escaping (Int) -> Void,
         onTransition: @escaping () -> Void) {
        self.scene = scene
        self.settings = settings
        self.coordinator = coordinator
        self.onPoints = onPoints
        self.onTransition = onTransition
    }
    
    deinit { runTask?.cancel() }
    
    // MARK: - Public
    
    func triggerTransition() {
        updateSaveState()
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
    
    // NEW: Load from saved state
    func loadState(nodeIndex: Int, bubbles: [ChatBubble]) {
        self.nodeIndex = nodeIndex
        self.bubbles = bubbles
        self.choices = []
        self.choicesVisible = false
        self.isTyping = false
        print("📥 TextSceneVM: Loaded state - nodeIndex=\(self.nodeIndex), bubbles=\(bubbles.count)")
        
        // Check if we need to continue or if we're waiting at a choice
        guard self.nodeIndex < scene.nodes.count else {
            print("📥 TextSceneVM: At end of scene, showing transition button")
            showTransitionButton = true
            return
        }
        
        let currentNode = scene.nodes[self.nodeIndex]
        print("📥 TextSceneVM: Current node type=\(currentNode.type)")
        
        // If we're at a player choice node, show the choices immediately
        if currentNode.type == "player_choice" {
            print("📥 TextSceneVM: Restoring choices at node \(self.nodeIndex)")
            runTask = Task {
                await showChoices(currentNode)
            }
            return
        }
        
        // If the current node is a transition trigger, show the button
        if currentNode.type == "message_block", currentNode.systemEvent == "transition_to_encounter" {
            print("📥 TextSceneVM: At transition node, showing button")
            showTransitionButton = true
            return
        }
        
        // For message_block or system_event nodes, their content is already in bubbles
        // So we can just continue from the current position
        print("📥 TextSceneVM: Continuing from node \(self.nodeIndex)")
        driveFromCurrent()
    }
    
    // NEW: Update coordinator's save state
    private func updateSaveState() {
        coordinator?.savedTextSceneState = (nodeIndex, bubbles)
    }
    
    func selectChoice(_ choice: ActiveChoice) {
        // Cancel existing task first
        runTask?.cancel()
        
        // Hide choices immediately when player taps
        withAnimation(G.appear) {
            choicesVisible = false
            choices = []
        }
        
        // Add points
        onPoints(choice.points)
        
        let currentNode = scene.nodes[nodeIndex]
        guard let option = currentNode.options?.first(where: { $0.optionId == choice.tag }) else {
            // Show player typing indicator, then message
            runTask = Task {
                let typingDelay = settings.pacing.typingDelayNs(charCount: choice.text.count)
                
                // Show typing indicator
                withAnimation(G.appear) { isPlayerTyping = true }
                try? await Task.sleep(nanoseconds: typingDelay)
                withAnimation(G.appear) { isPlayerTyping = false }
                
                // Show player message
                withAnimation(G.appear) {
                    bubbles.append(ChatBubble(kind: .player, text: choice.text))
                }
                
                try? await Task.sleep(nanoseconds: 300_000_000) // Brief pause after player message
                nodeIndex += 1
                updateSaveState()  // Save after node advancement (includes player message)
                await continueFromCurrent()
            }
            return
        }
        
        runTask = Task { @MainActor in
            print("🔵 selectChoice: Starting task for choice '\(choice.text)'")
            
            let typingDelay = settings.pacing.typingDelayNs(charCount: choice.text.count)
            
            // Show typing indicator for player
            withAnimation(G.appear) { isPlayerTyping = true }
            try? await Task.sleep(nanoseconds: typingDelay)
            withAnimation(G.appear) { isPlayerTyping = false }
            
            // Show player message
            withAnimation(G.appear) {
                bubbles.append(ChatBubble(kind: .player, text: choice.text))
            }
            
            // Brief pause after player message appears
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            
            // Advance nodeIndex now that choice has been made
            nodeIndex += 1
            print("🔵 selectChoice: Advanced to node index \(nodeIndex) after choice")
            
            // Handle branch messages if present
            if let branchMsgs = option.branchMessages, !branchMsgs.isEmpty {
                print("🔵 selectChoice: Found \(branchMsgs.count) branch messages")
                
                // Show response delay (NPC thinking about your choice)
                try? await Task.sleep(nanoseconds: settings.pacing.responseDelayNs)
                
                // Show each message naturally with typing indicator
                for (i, msg) in branchMsgs.enumerated() {
                    let msgText = msg.l(settings.language)
                    let typingDelay = settings.pacing.typingDelayNs(charCount: msgText.count)
                    
                    // Show typing indicator
                    isTyping = true
                    try? await Task.sleep(nanoseconds: typingDelay)
                    isTyping = false
                    
                    // Show the message
                    withAnimation(G.appear) {
                        bubbles.append(ChatBubble(kind: .npc, text: msgText))
                    }
                    updateSaveState()  // Save after each branch message
                    print("🔵 selectChoice: Displayed branch message \(i + 1)/\(branchMsgs.count)")
                    
                    // Delay between messages
                    if i < branchMsgs.count - 1 {
                        try? await Task.sleep(nanoseconds: settings.pacing.interMessageDelayNs)
                    }
                }
            } else {
                // No branch messages, save state after advancing node
                updateSaveState()
            }
            
            // Small delay before checking what's next
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            // Check if we've reached the end
            guard nodeIndex < scene.nodes.count else {
                print("🔵 selectChoice: Reached end of nodes, showing transition button")
                showTransitionButton = true
                updateSaveState()
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
                updateSaveState()  // Save after each message block
                
                // Transition event
                if node.systemEvent == "transition_to_encounter" {
                    print("🟢 continueFromCurrent: Found transition event, showing button")
                    let wait = settings.pacing == .fast ? UInt64(100_000_000) : UInt64(800_000_000)
                    try? await Task.sleep(nanoseconds: wait)
                    showTransitionButton = true
                    updateSaveState()  // Save before showing button
                    return
                }
                
                // Add small delay before checking for choices
                try? await Task.sleep(nanoseconds: 200_000_000)
                
                // If next node is a choice, present it and wait for player
                if nodeIndex + 1 < scene.nodes.count,
                   scene.nodes[nodeIndex + 1].type == "player_choice" {
                    print("🟢 continueFromCurrent: Next node is a choice, showing choices")
                    nodeIndex += 1
                    updateSaveState()  // Save before showing choices
                    await showChoices(scene.nodes[nodeIndex])
                    return
                }
                nodeIndex += 1
                updateSaveState()  // Save after advancing node
                
            case "player_choice":
                print("🟢 continueFromCurrent: Current node is a choice, showing choices")
                updateSaveState()  // Save before showing choices
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
                    updateSaveState()  // Save after system message
                    try? await Task.sleep(nanoseconds: settings.pacing == .fast ? 300_000_000 : 1_200_000_000)
                }
                nodeIndex += 1
                updateSaveState()  // Save after advancing node
                
            default:
                print("🟢 continueFromCurrent: Unknown node type, skipping")
                nodeIndex += 1
                updateSaveState()  // Save after advancing node
            }
        }
        
        print("🟢 continueFromCurrent: Reached end of nodes, showing transition button")
        showTransitionButton = true
        updateSaveState()  // Save when complete
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
            // First, show a small response delay (NPC picking up phone)
            try? await Task.sleep(nanoseconds: settings.pacing.responseDelayNs)
            
            // Then show typing indicator for each message
            for (i, msg) in messages.enumerated() {
                let msgText = msg.l(lang)
                let typingDelay = settings.pacing.typingDelayNs(charCount: msgText.count)
                
                // Show typing indicator
                isTyping = true
                try? await Task.sleep(nanoseconds: typingDelay)
                isTyping = false
                
                // Show the message with smooth animation
                withAnimation(G.appear) {
                    bubbles.append(ChatBubble(kind: kind, text: msgText))
                }
                updateSaveState()  // Save after each message
                
                // Small delay between multiple messages
                if i < messages.count - 1 {
                    try? await Task.sleep(nanoseconds: settings.pacing.interMessageDelayNs)
                }
            }
        } else {
            // Player messages - show typing indicator before each one
            for (i, msg) in messages.enumerated() {
                let msgText = msg.l(lang)
                let typingDelay = settings.pacing.typingDelayNs(charCount: msgText.count)
                
                // Show player typing indicator
                isPlayerTyping = true
                try? await Task.sleep(nanoseconds: typingDelay)
                isPlayerTyping = false
                
                // Show the message
                withAnimation(G.appear) {
                    bubbles.append(ChatBubble(kind: kind, text: msgText))
                }
                updateSaveState()  // Save after each message
                if i < messages.count - 1 {
                    try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s between player messages
                }
            }
        }
        
        // Scripted response delay (when NPC is away/sleeping/busy)
        if isPlayer, let delayMs = node.responseDelayMs {
            let scriptedDelay = settings.pacing.scriptedDelayNs(baseMs: delayMs)
            if scriptedDelay > 500_000_000 { // Only show typing if delay is noticeable
                isTyping = true
                try? await Task.sleep(nanoseconds: scriptedDelay)
                isTyping = false
            } else {
                try? await Task.sleep(nanoseconds: scriptedDelay)
            }
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
