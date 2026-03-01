//
//  SettingsManager.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//

import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english  = "en"
    case italian  = "it"
    case georgian = "ka"
    case persian  = "fa"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .english:  return "🇬🇧  English"
        case .italian:  return "🇮🇹  Italiano"
        case .georgian: return "🇬🇪  ქართული"
        case .persian:  return "🇮🇷  فارسی"
        }
    }
    
    var isRTL: Bool { self == .persian }
    var direction: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
    var alignment: TextAlignment   { isRTL ? .trailing : .leading }
    var hAlign: HorizontalAlignment { isRTL ? .trailing : .leading }
}

enum Pacing: String, CaseIterable, Identifiable, Codable {
    case fast   = "fast"
    case medium = "medium"
    case native = "native"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .fast:   return "Fast"
        case .medium: return "Medium"
        case .native: return "Native"
        }
    }
    
    // Typing indicator duration - simulates NPC typing
    func typingDelayNs(charCount: Int) -> UInt64 {
        let chars = max(charCount, 10) // Minimum 10 chars for calculation
        switch self {
        case .fast:
            // Fast: quick typing (30 chars/sec) + 0.3-0.8s base
            let secs = min(max(Double(chars) / 30.0, 0.3), 0.8)
            return UInt64(secs * 1_000_000_000)
        case .medium:
            // Medium: moderate typing (20 chars/sec) + 0.5-2s base
            let secs = min(max(Double(chars) / 20.0, 0.5), 2.0)
            return UInt64(secs * 1_000_000_000)
        case .native:
            // Native: realistic typing (15 chars/sec) + 0.8-3.5s base
            let secs = min(max(Double(chars) / 15.0, 0.8), 3.5)
            return UInt64(secs * 1_000_000_000)
        }
    }
    
    // Delay before NPC starts typing (simulates "picking up phone" or "thinking")
    var responseDelayNs: UInt64 {
        switch self {
        case .fast:   return 200_000_000   // 0.2s - nearly instant
        case .medium: return 800_000_000   // 0.8s - slight pause
        case .native: return 1_500_000_000 // 1.5s - realistic pause
        }
    }
    
    // Additional "thinking" delay when player texts and NPC is away/sleeping
    func scriptedDelayNs(baseMs: Int?) -> UInt64 {
        guard let ms = baseMs, ms > 0 else { return responseDelayNs }
        let baseNs = UInt64(ms) * 1_000_000
        switch self {
        case .fast:   return min(baseNs / 4, 1_000_000_000)  // Quarter time, max 1s
        case .medium: return min(baseNs / 2, 3_000_000_000)  // Half time, max 3s
        case .native: return min(baseNs, 8_000_000_000)      // Full time, max 8s
        }
    }
    
    // Delay between multiple messages in a row
    var interMessageDelayNs: UInt64 {
        switch self {
        case .fast:   return 200_000_000   // 0.2s
        case .medium: return 400_000_000   // 0.4s
        case .native: return 600_000_000   // 0.6s
        }
    }
    
    // Encounter-specific delays
    func encounterNs(baseMs: Int?) -> UInt64 {
        guard let ms = baseMs, ms > 0 else { return responseDelayNs }
        switch self {
        case .fast:   return min(UInt64(ms) * 250_000, 500_000_000)      // ~25%, max 0.5s
        case .medium: return min(UInt64(ms) * 500_000, 2_000_000_000)    // ~50%, max 2s
        case .native: return min(UInt64(ms) * 1_000_000, 5_000_000_000)  // 100%, max 5s
        }
    }
    
    var transitionNs: UInt64 {
        switch self {
        case .fast:   return 0
        case .medium: return 1_500_000_000
        case .native: return 2_500_000_000
        }
    }
}


@Observable
@MainActor
final class SettingsManager {
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "aware_lang")
        }
    }
    
    var pacing: Pacing {
        didSet {
            UserDefaults.standard.set(pacing.rawValue, forKey: "aware_pace")
        }
    }
    
    init() {
        let savedLang = UserDefaults.standard.string(forKey: "aware_lang")
        self.language = savedLang.flatMap(AppLanguage.init) ?? .english
        
        let savedPace = UserDefaults.standard.string(forKey: "aware_pace")
        self.pacing = savedPace.flatMap(Pacing.init) ?? .medium
    }
}
