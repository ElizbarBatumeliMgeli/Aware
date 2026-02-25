//
//  Models.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//
// Models.swift
// AWARE — Data Models

import Foundation

// MARK: ─── Localized Text ───────────────────────────────────────────

struct LText: Codable {
    let en: String
    let it: String
    let ka: String
    let fa: String
    
    func l(_ lang: AppLanguage) -> String {
        switch lang {
        case .english:  return en
        case .italian:  return it
        case .georgian: return ka
        case .persian:  return fa
        }
    }
}

// MARK: ─── Text Message Scene ───────────────────────────────────────

struct TextScene: Codable {
    let chapter: Int
    let sceneId: String
    let sceneType: String
    let characters: [String]
    let nodes: [TextNode]
    
    enum CodingKeys: String, CodingKey {
        case chapter
        case sceneId = "scene_id"
        case sceneType = "scene_type"
        case characters, nodes
    }
}

struct TextNode: Codable, Identifiable {
    let id: String
    let type: String
    let sender: String?
    let messages: [LText]?
    let responseDelayMs: Int?
    let systemEvent: String?
    let options: [TextChoiceOption]?
    let event: String?
    let label: LText?
    
    enum CodingKeys: String, CodingKey {
        case id, type, sender, messages, options, event, label
        case responseDelayMs = "response_delay_ms"
        case systemEvent = "system_event"
    }
}

struct TextChoiceOption: Codable, Identifiable {
    let optionId: String
    let text: LText
    let points: Int
    let responseDelayMs: Int?
    let branchMessages: [LText]?
    
    var id: String { optionId }
    
    enum CodingKeys: String, CodingKey {
        case optionId = "option_id"
        case text, points
        case responseDelayMs = "response_delay_ms"
        case branchMessages = "branch_messages"
    }
}

// MARK: ─── Encounter Scene ──────────────────────────────────────────

struct EncounterScene: Codable {
    let chapter: Int
    let sceneId: String
    let sceneType: String
    let location: LText
    let atmosphere: LText
    let nodes: [EncounterNode]
    let endings: EncounterEndings
    
    enum CodingKeys: String, CodingKey {
        case chapter
        case sceneId = "scene_id"
        case sceneType = "scene_type"
        case location, atmosphere, nodes, endings
    }
}

struct EncounterNode: Codable, Identifiable {
    let id: String
    let type: String
    let speaker: String?
    let description: LText?
    let lines: [LText]?
    let narrativeAction: LText?
    let reactionDelayMs: Int?
    let options: [EncounterChoiceOption]?
    let event: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, speaker, description, lines, options, event
        case narrativeAction = "narrative_action"
        case reactionDelayMs = "reaction_delay_ms"
    }
}

struct EncounterChoiceOption: Codable, Identifiable {
    let optionId: String
    let text: LText
    let points: Int
    let reactionDelayMs: Int?
    let branchNarrative: LText?
    let branchLines: [LText]?
    
    var id: String { optionId }
    
    enum CodingKeys: String, CodingKey {
        case optionId = "option_id"
        case text, points
        case reactionDelayMs = "reaction_delay_ms"
        case branchNarrative = "branch_narrative"
        case branchLines = "branch_lines"
    }
}

struct EncounterEndings: Codable {
    let good: Ending
    let neutral: Ending
    let bad: Ending
}

struct Ending: Codable {
    let threshold: Int
    let postSceneLabel: LText
    let finalTexts: [LText]
    
    enum CodingKeys: String, CodingKey {
        case threshold
        case postSceneLabel = "post_scene_label"
        case finalTexts = "final_texts"
    }
}

// MARK: ─── UI Display Models ────────────────────────────────────────

struct ChatBubble: Identifiable, Equatable {
    let id = UUID()
    let kind: BubbleKind
    let text: String
    static func == (lhs: ChatBubble, rhs: ChatBubble) -> Bool { lhs.id == rhs.id }
}

enum BubbleKind: Equatable {
    case npc
    case player
    case narrative
    case action
    case system
    case endingGood
    case endingNeutral
    case endingBad
}

struct ActiveChoice: Identifiable {
    let id = UUID()
    let text: String
    let points: Int
    let tag: String
}

// MARK: ─── JSON Loader ──────────────────────────────────────────────

enum SceneLoader {
    static func loadTextScene(named name: String) -> TextScene? { load(name) }
    static func loadEncounter(named name: String) -> EncounterScene? { load(name) }
    
    private static func load<T: Decodable>(_ name: String) -> T? {
        if let url = Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
