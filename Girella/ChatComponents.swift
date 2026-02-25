//
//  ChatComponents.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

// ChatComponents.swift
// AWARE — Shared Chat UI Components (pure Swift Concurrency, warm boxes)

import SwiftUI

// MARK: ─── Top Bar ──────────────────────────────────────────────────

struct TopBar: View {
    let title: String
    let accent: Color
    let onExit: () -> Void
    
    @State private var glow: Double = 0.3
    
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
            
            Spacer()
            
            // Invisible balance element
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(.caption2))
                    .imageScale(.small)
                Text("EXIT").font(G.dynamicMono(.caption2)).tracking(2)
            }.opacity(0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .onAppear { withAnimation(G.pulse) { glow = 0.7 } }
    }
}

// MARK: ─── Message Bubble (warm boxed) ──────────────────────────────

struct BubbleView: View {
    let bubble: ChatBubble
    let lang: AppLanguage
    
    var body: some View {
        switch bubble.kind {
        case .npc:          npcBox
        case .player:       playerBox
        case .narrative:    narrativeBox
        case .action:       actionText
        case .system:       systemText
        case .endingGood, .endingNeutral, .endingBad: endingBox
        }
    }
    
    // ── Andreas: warm sage box, left ──
    private var npcBox: some View {
        HStack {
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
                .containerRelativeFrame(.horizontal, alignment: .leading) { length, axis in
                    length * 0.78
                }
            
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
                .containerRelativeFrame(.horizontal, alignment: .leading) { length, axis in
                    length * 0.78
                }
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
                        .fill(G.warm.opacity(i <= phase ? 0.7 : 0.15))
                        .frame(width: 4, height: 4)
                        .animation(.easeInOut(duration: 0.2), value: phase)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .onAppear {
            animTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    phase = (phase + 1) % 3
                }
            }
        }
        .onDisappear { animTask?.cancel() }
    }
}

// MARK: ─── Thinking Indicator (encounter) ───────────────────────────

struct ThinkingDots: View {
    @State private var opacity: Double = 0.25
    
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
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                opacity = 0.65
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
