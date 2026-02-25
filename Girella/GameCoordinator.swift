//
//  GameCoordinator.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

// GameCoordinator.swift
// AWARE — Top-level game state & scene transitions

import SwiftUI

enum GamePhase: Equatable {
    case textScene
    case transitionToEncounter
    case encounter
    case epilogue
}

@Observable
@MainActor
final class GameCoordinator {
    let id = UUID() // Add ID for debugging
    var phase: GamePhase = .textScene
    var totalScore: Int = 0
    
    let settings: SettingsManager
    let textScene: TextScene
    let encounterScene: EncounterScene
    
    init(settings: SettingsManager) {
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
