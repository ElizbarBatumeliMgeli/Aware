//
//  ChatComponents.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

import SwiftUI

struct TopBar: View {
    let title: String
    let accent: Color
    let onExit: () -> Void
    
    @State private var glow: Double = 0.3
    @State private var showProfileSheet = false
    
    var body: some View {
        HStack {
            Button(action: onExit) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .imageScale(.small)
                    Text("EXIT").font(G.dynamicMono(.caption2, .medium)).tracking(2)
                }
                .foregroundColor(G.text2)
            }
            
            Spacer()
            
            // Profile Button on the right
            Button {
                showProfileSheet = true
            } label: {
                Image("andreas_profile")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(G.npcBorder, lineWidth: 1)
                    )
            }
            .sheet(isPresented: $showProfileSheet) {
                AndreasProfileView()
            }
        }
        // Use overlay to keep title perfectly mathematically centered regardless of button widths
        .overlay(
            HStack(spacing: 7) {
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                    .shadow(color: accent.opacity(glow), radius: 4)
                Text(title)
                    .font(G.dynamicMono(.caption, .semibold))
                    .tracking(3)
                    .foregroundColor(accent)
            }
        )
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .onAppear { withAnimation(G.pulse) { glow = 0.7 } }
    }
}

// MARK: ─── Profile & Relationship View ──────────────────────────────

struct AndreasProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            G.bg.ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Drag Handle
                Capsule()
                    .fill(G.dim.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 14)
                
                // Profile Image
                Image("andreas_profile")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(G.npcBorder, lineWidth: 2)
                    )
                    .shadow(color: G.npcBorder.opacity(0.2), radius: 8)
                
                Text("ANDREAS")
                    .font(G.dynamicMono(.title3, .semibold))
                    .tracking(4)
                    .foregroundColor(G.text1)
                
                // Meters
                VStack(spacing: 32) {
                    StatRow(
                        title: "TRUST",
                        level: 1,
                        maxLevel: 10,
                        activeColor: .yellow,
                        symbol: "shield.fill"
                    )
                    
                    StatRow(
                        title: "FRIENDSHIP",
                        level: 5,
                        maxLevel: 10,
                        activeColor: .pink,
                        symbol: "heart.fill"
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.hidden) // Hidden because we draw our own capsule handle
    }
}

struct StatRow: View {
    let title: String
    let level: Int
    let maxLevel: Int
    let activeColor: Color
    let symbol: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(G.dynamicMono(.caption, .semibold))
                    .tracking(3)
                    .foregroundColor(G.text2)
                Spacer()
                Text("\(level)/\(maxLevel)")
                    .font(G.dynamicMono(.caption2, .medium))
                    .foregroundColor(G.dim)
            }
            
            HStack(spacing: 6) {
                ForEach(0..<maxLevel, id: \.self) { i in
                    ZStack {
                        // Outer Circle
                        Circle()
                            .stroke(i < level ? activeColor.opacity(0.8) : G.dim.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        
                        // Inner Symbol
                        if i < level {
                            Image(systemName: symbol)
                                .font(.system(size: 10))
                                .foregroundColor(activeColor)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}


// MARK: ─── Message Bubble (warm boxed) ──────────────────────────────

struct BubbleView: View {
    let bubble: ChatBubble
    let lang: AppLanguage
    let showProfileImage: Bool
    
    init(bubble: ChatBubble, lang: AppLanguage, showProfileImage: Bool = false) {
        self.bubble = bubble
        self.lang = lang
        self.showProfileImage = showProfileImage
    }
    
    var body: some View {
            switch bubble.kind {
            case .npc:          npcBox
            case .player:       playerBox
            case .narrative:    narrativeBox
            case .action:       actionText
            case .system:       systemText
            case .endingGood, .endingNeutral, .endingBad: endingBox
            case .image:        SceneImageBubble(imageName: bubble.text) // <--- ADD THIS LINE
            }
        }
    
    // ── Andreas: warm sage box with profile image, left ──
    private var npcBox: some View {
        HStack(alignment: .bottom, spacing: 8) {
            
            // Profile image OR Invisible placeholder for alignment
            if showProfileImage {
                Image("andreas_profile")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(G.npcBorder, lineWidth: 1.5)
                    )
                    .padding(.bottom, 2)
            } else {
                // INSTAGRAM ALIGNMENT: Empty space so bubbles align nicely
                Color.clear
                    .frame(width: 36, height: 36)
                    .padding(.bottom, 2)
            }
            
            Text(bubble.text)
                .font(G.dynamicMono(.subheadline))
                .foregroundColor(G.npcText)
                .multilineTextAlignment(lang.alignment)
                .lineSpacing(4)
                .padding(.vertical, 10)
                .padding(.horizontal, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(G.npcBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(G.npcBorder, lineWidth: 0.5)
                )
            
            Spacer(minLength: 30)
        }
    }
    
    // ── Player: warm peach box, right ──
    private var playerBox: some View {
        HStack {
            Spacer(minLength: 30)
            
            Text(bubble.text)
                .font(G.dynamicMono(.subheadline))
                .foregroundColor(G.playerText)
                .multilineTextAlignment(lang.isRTL ? .leading : .trailing)
                .lineSpacing(4)
                .padding(.vertical, 10)
                .padding(.horizontal, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(G.playerBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(G.playerBorder, lineWidth: 0.5)
                )
        }
    }
    
    // ── Narrative description: amber warm box ──
    private var narrativeBox: some View {
        Text(bubble.text)
            .font(G.dynamicMono(.caption).italic())
            .foregroundColor(G.amber)
            .multilineTextAlignment(lang.alignment)
            .lineSpacing(5)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(G.amber.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(G.amber.opacity(0.1), lineWidth: 0.5)
            )
    }
    
    // ── Action: dim italic, no box ──
    private var actionText: some View {
        Text(bubble.text)
            .font(G.dynamicMono(.caption).italic())
            .foregroundColor(G.dim)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)
    }
    
    // ── System: centered label ──
    private var systemText: some View {
        Text(bubble.text)
            .font(G.dynamicMono(.caption2, .medium))
            .foregroundColor(G.dim)
            .tracking(2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
    
    // ── Ending messages: warm themed box ──
    private var endingBox: some View {
        let color: Color = {
            switch bubble.kind {
            case .endingGood:    return G.good
            case .endingNeutral: return G.neutral
            case .endingBad:     return G.bad
            default:             return G.dim
            }
        }()
        
        return HStack {
            Text(bubble.text)
                .font(G.dynamicMono(.subheadline))
                .foregroundColor(color)
                .lineSpacing(4)
                .padding(.vertical, 10)
                .padding(.horizontal, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                )
            Spacer(minLength: 30)
        }
    }
}

// MARK: ─── Typing Indicator (pure async, no Combine) ────────────────

struct TypingDots: View {
    let label: String
    @State private var phase = 0
    @State private var animTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(G.dynamicMono(.caption2))
                .foregroundColor(G.dim)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(G.warm.opacity(dotOpacity(for: i)))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .onAppear {
            animTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = (phase + 1) % 4 // 0, 1, 2, 3 (3 is all off)
                    }
                }
            }
        }
        .onDisappear { animTask?.cancel() }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        if phase == 3 { return 0.15 }
        return index == phase ? 0.75 : 0.2
    }
}

// MARK: ─── Andreas Typing Indicator (Instagram-style with profile image) ───

struct AndreasTypingIndicator: View {
    @State private var phase = 0
    @State private var animTask: Task<Void, Never>?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Profile image
            Image("andreas_profile")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(G.npcBorder, lineWidth: 1.5)
                )
            
            // Typing bubble with animated dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(G.npcText.opacity(dotOpacity(for: i)))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(G.npcBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(G.npcBorder, lineWidth: 0.5)
            )
            
            Spacer(minLength: 30)
        }
        .onAppear {
            animTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        phase = (phase + 1) % 4
                    }
                }
            }
        }
        .onDisappear { animTask?.cancel() }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        if phase == 3 { return 0.25 }
        return index == phase ? 0.85 : 0.3
    }
}

// MARK: ─── Player Typing Indicator ──────────────────────────────────

struct PlayerTypingDots: View {
    @State private var phase = 0
    @State private var animTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 4) {
            Spacer()
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(G.playerBorder.opacity(dotOpacity(for: i)))
                        .frame(width: 4, height: 4)
                }
            }
            Text("you are typing")
                .font(G.dynamicMono(.caption2))
                .foregroundColor(G.dim)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 4)
        .onAppear {
            animTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = (phase + 1) % 4
                    }
                }
            }
        }
        .onDisappear { animTask?.cancel() }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        if phase == 3 { return 0.2 }
        return index == phase ? 0.85 : 0.25
    }
}

// MARK: ─── Center Typing Indicator (for middle area) ────────────────

struct CenterTypingIndicator: View {
    let text: String
    let color: Color
    
    @State private var phase = 0
    @State private var animTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 6) {
            Spacer()
            Text(text)
                .font(G.dynamicMono(.caption2, .medium))
                .tracking(2)
                .foregroundColor(G.dim.opacity(0.6))
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(color.opacity(dotOpacity(for: i)))
                        .frame(width: 3, height: 3)
                }
            }
            Spacer()
        }
        .onAppear {
            animTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        phase = (phase + 1) % 4
                    }
                }
            }
        }
        .onDisappear { animTask?.cancel() }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        if phase == 3 { return 0.25 }
        return index == phase ? 0.75 : 0.2
    }
}

// MARK: ─── Thinking Indicator (encounter) ───────────────────────────

struct ThinkingDots: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 6) {
            Text("· · ·")
                .font(G.dynamicMono(.body, .medium))
                .foregroundColor(G.warm.opacity(opacity))
            Text("Andreas pauses")
                .font(G.dynamicMono(.caption2).italic())
                .foregroundColor(G.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 0.7
            }
        }
    }
}

// MARK: ─── Choice Panel ─────────────────────────────────────────────

struct ChoicePanel: View {
    let choices: [ActiveChoice]
    let lang: AppLanguage
    let onSelect: (ActiveChoice) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Rectangle().fill(G.warm.opacity(0.1)).frame(height: 1)
            
            ForEach(choices) { c in
                ChoiceBtn(text: c.text, lang: lang) { onSelect(c) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(G.surface.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: ─── Choice Button ────────────────────────────────────────────

struct ChoiceBtn: View {
    let text: String
    let lang: AppLanguage
    let action: () -> Void
    
    @State private var lit = false
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(G.dynamicMono(.subheadline))
                .foregroundColor(lit ? G.warm : G.text1)
                .multilineTextAlignment(lang.alignment)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: lang.isRTL ? .trailing : .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(lit ? G.warm.opacity(0.08) : G.surfaceLit.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(lit ? G.warm.opacity(0.5) : G.dim.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(WarmBtnStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { p in
            withAnimation(.easeOut(duration: 0.1)) { lit = p }
        }, perform: {})
    }
}
