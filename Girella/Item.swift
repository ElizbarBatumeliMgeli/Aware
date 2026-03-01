//
//  Item.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
// MARK: - Game Save Model

@Model
final class GameSave {
    var id: UUID
    var timestamp: Date
    var phase: String  // "textScene", "transitionToEncounter", "encounter", "epilogue"
    var totalScore: Int
    
    // Text scene state
    var textSceneNodeIndex: Int
    var textSceneBubblesJSON: Data?  // Encoded [ChatBubble]
    
    // Encounter state  
    var encounterNodeIndex: Int
    var encounterBubblesJSON: Data?  // Encoded [ChatBubble]
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         phase: String,
         totalScore: Int,
         textSceneNodeIndex: Int,
         encounterNodeIndex: Int,
         textSceneBubblesJSON: Data? = nil,
         encounterBubblesJSON: Data? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.phase = phase
        self.totalScore = totalScore
        self.textSceneNodeIndex = textSceneNodeIndex
        self.encounterNodeIndex = encounterNodeIndex
        self.textSceneBubblesJSON = textSceneBubblesJSON
        self.encounterBubblesJSON = encounterBubblesJSON
    }
}

