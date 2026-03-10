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
    var isPlayerTyping = false
    var isAndreasTyping = false
    
    private let scene: EncounterScene
    private let settings: SettingsManager
    private let onPoints: (Int) -> Void
    private let onFinish: () -> Void
    private weak var coordinator: GameCoordinator?
    
    private(set) var nodeIndex = 0
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
            
            // ─── ADD FIRST SCENE IMAGE ───
            bubbles.append(ChatBubble(kind: .image, text: "scene_1"))
        }
        
        runTask = Task {
            try? await Task.sleep(nanoseconds: settings.pacing == .fast ? 300_000_000 : 1_500_000_000)
            await driveFromCurrent()
        }
    }
    
    func loadState(nodeIndex: Int, bubbles: [ChatBubble]) {
        self.nodeIndex = nodeIndex
        self.bubbles = bubbles
        self.choices = []
        self.choicesVisible = false
        self.isThinking = false
        
        guard self.nodeIndex < scene.nodes.count else {
            onFinish()
            return
        }
        
        let currentNode = scene.nodes[self.nodeIndex]
        
        if currentNode.type == "player_choice" {
            showChoices(currentNode)
            return
        }
        
        if currentNode.type == "system_event" {
            onFinish()
            return
        }
        
        runTask = Task {
            await driveFromCurrent()
        }
    }
    
    private func updateSaveState() {
        coordinator?.savedEncounterState = (nodeIndex, bubbles)
    }
    
    func selectChoice(_ choice: ActiveChoice) {
        choicesVisible = false
        choices = []
        
        onPoints(choice.points)
        
        let node = scene.nodes[nodeIndex]
        guard let option = node.options?.first(where: { $0.optionId == choice.tag }) else {
            runTask = Task {
                let typingDelay = settings.pacing.typingDelayNs(charCount: choice.text.count)
                
                withAnimation(G.appear) { isPlayerTyping = true }
                try? await Task.sleep(nanoseconds: typingDelay)

                withAnimation(G.appear) {
                    isPlayerTyping = false
                    bubbles.append(ChatBubble(kind: .player, text: choice.text))
                }                
                try? await Task.sleep(nanoseconds: 300_000_000)
                advance()
            }
            return
        }
        
        let lang = settings.language
        
        runTask = Task {
            let typingDelay = settings.pacing.typingDelayNs(charCount: choice.text.count)
            
            withAnimation(G.appear) { isPlayerTyping = true }
            try? await Task.sleep(nanoseconds: typingDelay)

            withAnimation(G.appear) {
                isPlayerTyping = false
                bubbles.append(ChatBubble(kind: .player, text: choice.text))
            }            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if node.id == "choice_15" {
                withAnimation(G.appear) {
                    bubbles.append(ChatBubble(kind: .image, text: "scene_3"))
                }
                updateSaveState()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            nodeIndex += 1
            updateSaveState()
            
            let delay = settings.pacing.encounterNs(baseMs: option.reactionDelayMs)
            if delay > 500_000_000 {
                withAnimation(G.appear) { isThinking = true }
                try? await Task.sleep(nanoseconds: delay)
                withAnimation(G.appear) { isThinking = false }
            } else {
                try? await Task.sleep(nanoseconds: delay)
            }
            
            if let narr = option.branchNarrative {
                withAnimation(G.appear) {
                    bubbles.append(ChatBubble(kind: .action, text: narr.l(lang)))
                }
                updateSaveState()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            
            if let lines = option.branchLines {
                for (i, line) in lines.enumerated() {
                    let typingDelay = settings.pacing.typingDelayNs(charCount: line.l(lang).count)
                    withAnimation(G.appear) { isAndreasTyping = true }
                    try? await Task.sleep(nanoseconds: typingDelay)

                    withAnimation(G.appear) {
                        isAndreasTyping = false
                        bubbles.append(ChatBubble(kind: .npc, text: line.l(lang)))
                    }
                    updateSaveState()
                    if i < lines.count - 1 {
                        try? await Task.sleep(nanoseconds: settings.pacing.interMessageDelayNs)
                    }
                }
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000)
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
                        
                        // ─── ADD SECOND SCENE IMAGE ───
                        // (Injects exactly when node_21 triggers)
                        if node.id == "node_21" {
                            bubbles.append(ChatBubble(kind: .image, text: "scene_2"))
                        }
                    }
                    updateSaveState()
                    try? await Task.sleep(nanoseconds: settings.pacing.typingDelayNs(charCount: desc.l(lang).count))
                }
                nodeIndex += 1
                updateSaveState()
                
            case "dialogue_block":
                await emitDialogue(node)
                updateSaveState()
                if nodeIndex + 1 < scene.nodes.count, scene.nodes[nodeIndex + 1].type == "player_choice" {
                    nodeIndex += 1
                    updateSaveState()
                    showChoices(scene.nodes[nodeIndex])
                    return
                }
                nodeIndex += 1
                updateSaveState()
                
            case "player_choice":
                updateSaveState()
                showChoices(node)
                return
                
            case "system_event":
                updateSaveState()
                onFinish()
                return
                
            default:
                nodeIndex += 1
                updateSaveState()
            }
        }
        updateSaveState()
        onFinish()
    }
    
    private func emitDialogue(_ node: EncounterNode) async {
        let lang = settings.language
        let isPlayer = node.speaker == "Player"
        
        if let act = node.narrativeAction {
            withAnimation(G.appear) {
                bubbles.append(ChatBubble(kind: .action, text: act.l(lang)))
            }
            updateSaveState()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        
        if !isPlayer, let ms = node.reactionDelayMs {
            let delay = settings.pacing.encounterNs(baseMs: ms)
            if delay > 500_000_000 {
                withAnimation(G.appear) { isThinking = true }
                try? await Task.sleep(nanoseconds: delay)
                withAnimation(G.appear) { isThinking = false }
            } else {
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        
        if let lines = node.lines {
            let kind: BubbleKind = isPlayer ? .player : .npc
            
            if isPlayer {
                try? await Task.sleep(nanoseconds: settings.pacing.responseDelayNs / 2)
            }
            
            for (i, line) in lines.enumerated() {
                let typingDelay = settings.pacing.typingDelayNs(charCount: line.l(lang).count)
                if !isPlayer {
                    withAnimation(G.appear) { isAndreasTyping = true }
                    try? await Task.sleep(nanoseconds: typingDelay)
                    withAnimation(G.appear) {
                        isAndreasTyping = false
                        bubbles.append(ChatBubble(kind: kind, text: line.l(lang)))
                    }
                } else {
                    withAnimation(G.appear) { isPlayerTyping = true }
                    try? await Task.sleep(nanoseconds: typingDelay)
                    withAnimation(G.appear) {
                        isPlayerTyping = false
                        bubbles.append(ChatBubble(kind: kind, text: line.l(lang)))
                    }
                }
                updateSaveState()
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
        choices = opts.map { ActiveChoice(text: $0.text.l(lang), points: $0.points, tag: $0.optionId) }.shuffled()
        withAnimation(G.soft) { choicesVisible = true }
    }
    
    private func advance() {
        nodeIndex += 1
        runTask = Task { await driveFromCurrent() }
    }
}  
