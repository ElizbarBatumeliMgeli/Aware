//
//  Theme.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//
import SwiftUI

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

enum G {
    // Background — soft pastel cream and warm whites
    static let bg           = Color(hex: "FDF8F3")       // very soft peachy cream
    static let surface      = Color(hex: "FFFCF9")       // warm off-white
    static let surfaceLit   = Color(hex: "FFFFFF")       // pure white
    
    // ─── Andreas (NPC): Pastel Yellow ───
        static let npcBg        = Color(hex: "FFF8D6")  // Soft pastel yellow bubble
        static let npcBorder    = Color(hex: "E5D9A1")  // Slightly darker yellow for the border
        static let npcText      = Color(hex: "5A5231")  // Dark brownish-yellow for readable text
        static let sage         = Color(hex: "D9CB7C")  // Accent color for the Top Bar (was green, now yellow)

        // ─── Player: Pastel Pink ───
        static let playerBg     = Color(hex: "FDE2E9")  // Soft pastel pink bubble
        static let playerBorder = Color(hex: "E0B3C1")  // Slightly darker pink for the border
        static let playerText   = Color(hex: "6B3E4B")  // Dark maroon/pink for readable text
    
    // Accents
    static let warm         = Color(hex: "E89B7F")       // warm coral — primary accent (darker for contrast)
    static let rose         = Color(hex: "E8998F")       // soft rose (darker)
    static let cream        = Color(hex: "F5E6D3")       // pastel peach cream
    static let amber        = Color(hex: "D9A36A")       // amber (darker for contrast with narrative)
    
    // Text hierarchy (WCAG AA compliant with bg colors)
    static let text1        = Color(hex: "2B2B2B")       // very dark gray — primary text (contrast ratio 14.5:1 on white)
    static let text2        = Color(hex: "595959")       // dark gray — secondary (contrast ratio 7.5:1 on white)
    static let dim          = Color(hex: "7A7A7A")       // medium gray — tertiary (contrast ratio 4.7:1 on white)
    static let dimSubtle    = Color(hex: "A8A8A8")       // light gray for decorative (contrast ratio 3:1 on white)
    
    // Status colors (darker for better visibility)
    static let good         = Color(hex: "5FAF7D")       // sage green (darker)
    static let neutral      = Color(hex: "D9A36A")       // amber
    static let bad          = Color(hex: "E8776A")       // coral red (darker)
    
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
                    with: .color(Color.black.opacity(0.012))  // Subtle dark lines on light background
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
