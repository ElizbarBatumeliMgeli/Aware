//
//  EncounterVM.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

// EncounterVM.swift
// AWARE — In-Person Encounter Logic (pure Swift Concurrency)

import SwiftUI

@Observable
@MainActor
final class EncounterVM {
    
    var bubbles: [ChatBubble] = []
    var choices: [ActiveChoice] = []
    var choicesVisible = false
    var isThinking = false
    
    private let scene: EncounterScene
    private let settings: SettingsManager
    private let onPoints: (Int) -> Void
    private let onFinish: () -> Void
    
    private var nodeIndex = 0
    @ObservationIgnored
    private var runTask: Task<Void, Never>?
    
    init(scene: EncounterScene,
         settings: SettingsManager,
         onPoints: @escaping (Int) -> Void,
         onFinish: @escaping () -> Void) {
        self.scene = scene
        self.settings = settings
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
    
    func selectChoice(_ choice: ActiveChoice) {
        choicesVisible = false
        choices = []
        
        withAnimation(G.appear) {
            bubbles.append(ChatBubble(kind: .player, text: choice.text))
        }
        onPoints(choice.points)
        
        let node = scene.nodes[nodeIndex]
        guard let option = node.options?.first(where: { $0.optionId == choice.tag }) else {
            advance()
            return
        }
        
        let lang = settings.language
        
        runTask = Task {
            let delay = settings.pacing.encounterNs(baseMs: option.reactionDelayMs)
            if delay > 400_000_000 {
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
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            if let lines = option.branchLines {
                for (i, line) in lines.enumerated() {
                    withAnimation(G.appear) {
                        bubbles.append(ChatBubble(kind: .npc, text: line.l(lang)))
                    }
                    if i < lines.count - 1 {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
            
            try? await Task.sleep(nanoseconds: 400_000_000)
            advance()
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
                    try? await Task.sleep(nanoseconds: settings.pacing.ns(charCount: desc.l(lang).count))
                }
                nodeIndex += 1
                
            case "dialogue_block":
                await emitDialogue(node)
                if nodeIndex + 1 < scene.nodes.count, scene.nodes[nodeIndex + 1].type == "player_choice" {
                    nodeIndex += 1
                    showChoices(scene.nodes[nodeIndex])
                    return
                }
                nodeIndex += 1
                
            case "player_choice":
                showChoices(node)
                return
                
            case "system_event":
                onFinish()
                return
                
            default:
                nodeIndex += 1
            }
        }
        onFinish()
    }
    
    private func emitDialogue(_ node: EncounterNode) async {
        let lang = settings.language
        let isPlayer = node.speaker == "Player"
        
        if let act = node.narrativeAction {
            withAnimation(G.appear) {
                bubbles.append(ChatBubble(kind: .action, text: act.l(lang)))
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        
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
                if i < lines.count - 1 {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
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
