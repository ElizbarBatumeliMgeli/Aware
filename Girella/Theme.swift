//
//  Theme.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//
// Theme.swift
// AWARE — Warm Visual Theme

import SwiftUI

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Theme

enum G {
    // Background — deep warm charcoal, not pure black
    static let bg           = Color(hex: "191716")
    static let surface      = Color(hex: "231F1D")
    static let surfaceLit   = Color(hex: "2D2825")
    
    // NPC bubble — warm muted teal/sage
    static let npcBg        = Color(hex: "2A2E2B")
    static let npcBorder    = Color(hex: "5A7A6C").opacity(0.3)
    static let npcText      = Color(hex: "C8D5C7")      // soft sage text
    
    // Player bubble — warm peach tones
    static let playerBg     = Color(hex: "3A2D28")
    static let playerBorder = Color(hex: "8B6E5D").opacity(0.25)
    static let playerText   = Color(hex: "D4BFB0")      // warm cream
    
    // Accents
    static let warm         = Color(hex: "D4A574")       // warm peach/amber — primary accent
    static let sage         = Color(hex: "8BAF92")       // muted sage green
    static let rose         = Color(hex: "C4887A")       // soft muted rose
    static let cream        = Color(hex: "E8DDD0")       // warm off-white
    static let amber        = Color(hex: "D4A574")       // narrative accent (same as warm)
    
    // Text hierarchy
    static let text1        = Color(hex: "E8DDD0")       // cream — primary text
    static let text2        = Color(hex: "B5A899")       // warm muted — secondary
    static let dim          = Color(hex: "9B8D7E")       // warm gray — tertiary (improved contrast)
    static let dimSubtle    = Color(hex: "7A6F65")       // even dimmer for decorative elements only
    
    // Status
    static let good         = Color(hex: "8BAF92")       // sage
    static let neutral      = Color(hex: "D4A574")       // amber
    static let bad          = Color(hex: "C4887A")       // rose
    
    // MARK: - Fonts
    
    // Legacy fixed-size font (use sparingly, only for non-content UI)
    static func mono(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font {
        .system(size: size, weight: w, design: .monospaced)
    }
    
    // Dynamic Type-aware fonts (preferred for all user-facing text)
    static func dynamicMono(_ style: Font.TextStyle, _ w: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: w)
    }
    
    // Relative sizing with Dynamic Type support
    static func scaledMono(_ baseSize: CGFloat, relativeTo style: Font.TextStyle = .body, _ w: Font.Weight = .regular) -> Font {
        .system(size: baseSize, weight: w, design: .monospaced).relativeToStyle(style)
    }
    
    // MARK: - Animations
    static let appear: Animation = .spring(response: 0.4, dampingFraction: 0.75)
    static let soft: Animation   = .spring(response: 0.35, dampingFraction: 0.8)
    static let pulse: Animation  = .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
}

// MARK: - Font Extension for Relative Scaling

private extension Font {
    func relativeToStyle(_ style: Font.TextStyle) -> Font {
        // This creates a font that scales with the given text style
        return Font.system(style, design: .monospaced)
    }
}

// MARK: - Scanline Overlay (subtle warmth)

struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: 4) {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(Color.white.opacity(0.008))
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Button Style

struct WarmBtnStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
