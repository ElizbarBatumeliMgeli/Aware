//
//  GameCoordinator.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

import SwiftUI

enum GamePhase: Equatable {
    case textScene
    case transitionToEncounter
    case encounter
    case epilogue
}

struct HeartAnim: Identifiable {
    let id = UUID()
    let startPoint: CGPoint
    var phase: Int = 0 // 0: initial, 1: pop, 2: travel and disappear
}

@Observable
@MainActor
final class GameCoordinator {
    let id = UUID() // Add ID for debugging
    var phase: GamePhase = .textScene
    var totalScore: Int = 0
    
    var heartAnimations: [HeartAnim] = []
    
    let settings: SettingsManager
    let textScene: TextScene
    let encounterScene: EncounterScene
    
    // Change this line:
    var savedTextSceneState: (nodeIndex: Int, bubbles: [ChatBubble], unlockDate: Date?)?
    var savedEncounterState: (nodeIndex: Int, bubbles: [ChatBubble])?
    
    init(settings: SettingsManager, loadingFrom save: GameSave? = nil) {
        self.settings = settings
        self.textScene = SceneLoader.loadTextScene(named: "text_scene_01")
            ?? TextScene(chapter: 1, sceneId: "fallback", sceneType: "text_message_thread", characters: [], nodes: [])
        self.encounterScene = SceneLoader.loadEncounter(named: "encounter_01")
            ?? EncounterScene(
                chapter: 1, sceneId: "fallback", sceneType: "in_person_interaction",
                location: LText(en: "", it: "", ka: "", fa: ""),
                atmosphere: LText(en: "", it: "", ka: "", fa: ""),
                nodes: [],
                endings: EncounterEndings(
                    good: Ending(threshold: 14, postSceneLabel: LText(en: "", it: "", ka: "", fa: ""), finalTexts: []),
                    neutral: Ending(threshold: 8, postSceneLabel: LText(en: "", it: "", ka: "", fa: ""), finalTexts: []),
                    bad: Ending(threshold: 0, postSceneLabel: LText(en: "", it: "", ka: "", fa: ""), finalTexts: [])
                ))
        
        // Load saved state if available
        if let save = save {
            self.totalScore = save.totalScore
            self.phase = {
                switch save.phase {
                case "textScene": return .textScene
                case "transitionToEncounter": return .transitionToEncounter
                case "encounter": return .encounter
                case "epilogue": return .epilogue
                default: return .textScene
                }
            }()
            
            // Decode saved bubbles
                        if let textData = save.textSceneBubblesJSON,
                           let textBubbles = try? JSONDecoder().decode([ChatBubble].self, from: textData) {
                            // FIX: Pass 'nil' for the unlockDate since we aren't saving it to the database yet!
                            self.savedTextSceneState = (save.textSceneNodeIndex, textBubbles, nil)
                        }
            
            if let encounterData = save.encounterBubblesJSON,
               let encounterBubbles = try? JSONDecoder().decode([ChatBubble].self, from: encounterData) {
                self.savedEncounterState = (save.encounterNodeIndex, encounterBubbles)
            }
            
            print("✅ Loaded game: phase=\(save.phase), score=\(save.totalScore), textNodes=\(save.textSceneNodeIndex), encounterNodes=\(save.encounterNodeIndex)")
        }
    }
    
    func spawnHeart(at point: CGPoint) {
        let anim = HeartAnim(startPoint: point)
        heartAnimations.append(anim)
        let animId = anim.id
        
        Task {
            // Phase 1: pop up
            try? await Task.sleep(nanoseconds: 50_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    if let idx = self.heartAnimations.firstIndex(where: { $0.id == animId }) {
                        self.heartAnimations[idx].phase = 1
                    }
                }
            }
            
            // Phase 2: fly to top right and fade out
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.7)) {
                    if let idx = self.heartAnimations.firstIndex(where: { $0.id == animId }) {
                        self.heartAnimations[idx].phase = 2
                    }
                }
            }
            
            // Cleanup
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                self.heartAnimations.removeAll(where: { $0.id == animId })
            }
        }
    }
    
    func addPoints(_ p: Int) { totalScore += p }
    
    /// Called when text scene ends. In fast mode, skip straight to encounter.
    func advanceToTransition() {
        print("🟣 GameCoordinator[\(id)]: advanceToTransition called, pacing=\(settings.pacing)")
        if settings.pacing == .fast {
            // Skip the transition screen entirely
            print("🟣 GameCoordinator[\(id)]: Setting phase to .encounter")
            withAnimation(G.appear) { phase = .encounter }
        } else {
            print("🟣 GameCoordinator[\(id)]: Setting phase to .transitionToEncounter")
            withAnimation(G.appear) { phase = .transitionToEncounter }
        }
        print("🟣 GameCoordinator[\(id)]: Phase is now \(phase)")
    }
    
    func beginEncounter() {
        withAnimation(G.appear) { phase = .encounter }
    }
    
    func finishEncounter() {
        withAnimation(G.appear) { phase = .epilogue }
    }
    
    func restart() {
        totalScore = 0
        withAnimation(G.appear) { phase = .textScene }
    }
    
    var earnedEnding: Ending {
        let e = encounterScene.endings
        if totalScore >= e.good.threshold    { return e.good }
        if totalScore >= e.neutral.threshold { return e.neutral }
        return e.bad
    }
    
    var endingTier: String {
        let e = encounterScene.endings
        if totalScore >= e.good.threshold    { return "good" }
        if totalScore >= e.neutral.threshold { return "neutral" }
        return "bad"
    }
}
