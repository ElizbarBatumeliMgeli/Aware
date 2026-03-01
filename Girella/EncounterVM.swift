//
//  EncounterVM.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

import SwiftUI

@Observable
@MainActor
final class EncounterVM {
    
    var bubbles: [ChatBubble] = []
    var choices: [ActiveChoice] = []
    var choicesVisible = false
    var isThinking = false
    var isPlayerTyping = false  // NEW: Track player typing state
    
    private let scene: EncounterScene
    private let settings: SettingsManager
    private let onPoints: (Int) -> Void
    private let onFinish: () -> Void
    private weak var coordinator: GameCoordinator?  // NEW: Keep reference to update save state
    
    private(set) var nodeIndex = 0  // Make readable from outside
    @ObservationIgnored
    private var runTask: Task<Void, Never>?
    
    init(scene: EncounterScene,
         settings: SettingsManager,
         coordinator: GameCoordinator,
         onPoints: @escaping (Int) -> Void,
         onFinish: @escaping () -> Void) {
        self.scene = scene
        self.settings = settings
        self.coordinator = coordinator
        self.onPoints = onPoints
        self.onFinish = onFinish
    }
    
    deinit { 
        runTask?.cancel() 
    }
    
    // MARK: - Public
    
    func start() {
        nodeIndex = 0
        bubbles = []
        choices = []
        choicesVisible = false
        isThinking = false
        
        let lang = settings.language
        withAnimation(G.appear) {
            bubbles.append(ChatBubble(kind: .system, text: scene.location.l(lang)))
            bubbles.append(ChatBubble(kind: .action, text: scene.atmosphere.l(lang)))
        }
        
        runTask = Task {
            try? await Task.sleep(nanoseconds: settings.pacing == .fast ? 300_000_000 : 1_500_000_000)
            await driveFromCurrent()
        }
    }
    
    // NEW: Load from saved state
    func loadState(nodeIndex: Int, bubbles: [ChatBubble]) {
        self.nodeIndex = nodeIndex
        self.bubbles = bubbles
        self.choices = []
        self.choicesVisible = false
        self.isThinking = false
        print("📥 EncounterVM: Loaded state - nodeIndex=\(self.nodeIndex), bubbles=\(bubbles.count)")
        
        // Check if we need to continue or if we're waiting at a choice
        guard self.nodeIndex < scene.nodes.count else {
            print("📥 EncounterVM: At end of scene, finishing")
            onFinish()
            return
        }
        
        let currentNode = scene.nodes[self.nodeIndex]
        print("📥 EncounterVM: Current node type=\(currentNode.type)")
        
        // If we're at a player choice node, show the choices immediately
        if currentNode.type == "player_choice" {
            print("📥 EncounterVM: Restoring choices at node \(self.nodeIndex)")
            showChoices(currentNode)
            return
        }
        
        // If we're at a system event, finish
        if currentNode.type == "system_event" {
            print("📥 EncounterVM: At system event, finishing")
            onFinish()
            return
        }
        
        // Continue from the current position
        print("📥 EncounterVM: Continuing from node \(self.nodeIndex)")
        runTask = Task {
            await driveFromCurrent()
        }
    }
    
    // NEW: Update coordinator's save state
    private func updateSaveState() {
        coordinator?.savedEncounterState = (nodeIndex, bubbles)
    }
    
    func selectChoice(_ choice: ActiveChoice) {
        // Hide choices immediately
        choicesVisible = false
        choices = []
        
        // Add points
        onPoints(choice.points)
        
        let node = scene.nodes[nodeIndex]
        guard let option = node.options?.first(where: { $0.optionId == choice.tag }) else {
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
                
                try? await Task.sleep(nanoseconds: 300_000_000) // Brief pause
                advance()  // This will increment nodeIndex and save
            }
            return
        }
        
        let lang = settings.language
        
        runTask = Task {
            let typingDelay = settings.pacing.typingDelayNs(charCount: choice.text.count)
            
            // Show typing indicator for player
            withAnimation(G.appear) { isPlayerTyping = true }
            try? await Task.sleep(nanoseconds: typingDelay)
            withAnimation(G.appear) { isPlayerTyping = false }
            
            // Show player message
            withAnimation(G.appear) {
                bubbles.append(ChatBubble(kind: .player, text: choice.text))
            }
            
            // Brief pause after player message
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            // Advance nodeIndex now that choice has been made
            nodeIndex += 1
            updateSaveState()  // Save after advancing past the choice node
            
            let delay = settings.pacing.encounterNs(baseMs: option.reactionDelayMs)
            if delay > 500_000_000 {
                isThinking = true
                try? await Task.sleep(nanoseconds: delay)
                isThinking = false
            } else {
                try? await Task.sleep(nanoseconds: delay)
            }
            
            if let narr = option.branchNarrative {
                withAnimation(G.appear) {
                    bubbles.append(ChatBubble(kind: .action, text: narr.l(lang)))
                }
                updateSaveState()  // Save after narrative
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            
            if let lines = option.branchLines {
                for (i, line) in lines.enumerated() {
                    withAnimation(G.appear) {
                        bubbles.append(ChatBubble(kind: .npc, text: line.l(lang)))
                    }
                    updateSaveState()  // Save after each line
                    if i < lines.count - 1 {
                        try? await Task.sleep(nanoseconds: settings.pacing.interMessageDelayNs)
                    }
                }
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            // Continue processing (nodeIndex already advanced above)
            runTask = Task { await driveFromCurrent() }
        }
    }
    
    // MARK: - Processing
    
    private func driveFromCurrent() async {
        while nodeIndex < scene.nodes.count {
            if Task.isCancelled { return }
            let node = scene.nodes[nodeIndex]
            let lang = settings.language
            
            switch node.type {
            case "narrative_block":
                if let desc = node.description {
                    withAnimation(G.appear) {
                        bubbles.append(ChatBubble(kind: .narrative, text: desc.l(lang)))
                    }
                    updateSaveState()  // Save after narrative
                    try? await Task.sleep(nanoseconds: settings.pacing.typingDelayNs(charCount: desc.l(lang).count))
                }
                nodeIndex += 1
                updateSaveState()  // Save after advancing node
                
            case "dialogue_block":
                await emitDialogue(node)
                updateSaveState()  // Save after dialogue
                if nodeIndex + 1 < scene.nodes.count, scene.nodes[nodeIndex + 1].type == "player_choice" {
                    nodeIndex += 1
                    updateSaveState()  // Save before showing choices
                    showChoices(scene.nodes[nodeIndex])
                    return
                }
                nodeIndex += 1
                updateSaveState()  // Save after advancing node
                
            case "player_choice":
                updateSaveState()  // Save before showing choices
                showChoices(node)
                return
                
            case "system_event":
                updateSaveState()  // Save before finishing
                onFinish()
                return
                
            default:
                nodeIndex += 1
                updateSaveState()  // Save after advancing node
            }
        }
        updateSaveState()  // Save when complete
        onFinish()
    }
    
    private func emitDialogue(_ node: EncounterNode) async {
        let lang = settings.language
        let isPlayer = node.speaker == "Player"
        
        if let act = node.narrativeAction {
            withAnimation(G.appear) {
                bubbles.append(ChatBubble(kind: .action, text: act.l(lang)))
            }
            updateSaveState()  // Save after action
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        
        // For NPC, show thinking/reaction delay
        if !isPlayer, let ms = node.reactionDelayMs {
            let delay = settings.pacing.encounterNs(baseMs: ms)
            if delay > 500_000_000 {
                isThinking = true
                try? await Task.sleep(nanoseconds: delay)
                isThinking = false
            } else {
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        
        if let lines = node.lines {
            let kind: BubbleKind = isPlayer ? .player : .npc
            for (i, line) in lines.enumerated() {
                withAnimation(G.appear) {
                    bubbles.append(ChatBubble(kind: kind, text: line.l(lang)))
                }
                updateSaveState()  // Save after each line
                if i < lines.count - 1 {
                    try? await Task.sleep(nanoseconds: settings.pacing.interMessageDelayNs)
                }
            }
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
    }
    
    private func showChoices(_ node: EncounterNode) {
        guard let opts = node.options else { return }
        let lang = settings.language
        choices = opts.map { ActiveChoice(text: $0.text.l(lang), points: $0.points, tag: $0.optionId) }
        withAnimation(G.soft) { choicesVisible = true }
    }
    
    private func advance() {
        nodeIndex += 1
        runTask = Task { await driveFromCurrent() }
    }
}
