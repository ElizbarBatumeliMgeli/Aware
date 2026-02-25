//
//  SettingsManager.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//

// SettingsManager.swift
// AWARE — Persistent User Preferences

import SwiftUI

// MARK: - Language

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

// MARK: - Pacing

enum Pacing: String, CaseIterable, Identifiable, Codable {
    case fast   = "fast"
    case medium = "medium"
    case native = "native"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .fast:   return "⚡  Fast"
        case .medium: return "⏱  Medium (2 s)"
        case .native: return "💬  Native (typing)"
        }
    }
    
    /// Returns nanoseconds to sleep before showing the next NPC message.
    func ns(charCount: Int) -> UInt64 {
        switch self {
        case .fast:   return 150_000_000                              // 0.15 s — near-instant
        case .medium: return 2_000_000_000                            // 2 s
        case .native:
            let secs = min(max(Double(charCount) * 0.055, 0.8), 7.0)
            return UInt64(secs * 1_000_000_000)
        }
    }
    
    /// Delay for encounter reaction beats.
    func encounterNs(baseMs: Int?) -> UInt64 {
        guard let ms = baseMs, ms > 0 else { return ns(charCount: 20) }
        switch self {
        case .fast:   return 200_000_000
        case .medium: return UInt64(ms) * 1_000_000
        case .native: return UInt64(ms) * 1_000_000
        }
    }
    
    /// Transition screen wait: 0 for fast, brief otherwise.
    var transitionNs: UInt64 {
        switch self {
        case .fast:   return 0
        case .medium: return 1_500_000_000
        case .native: return 2_500_000_000
        }
    }
}

// MARK: - Manager

@Observable
@MainActor
final class SettingsManager {
    @ObservationIgnored @AppStorage("aware_lang") var language: AppLanguage = .english
    @ObservationIgnored @AppStorage("aware_pace") var pacing: Pacing = .medium
}
