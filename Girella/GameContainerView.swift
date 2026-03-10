//
//  GameContainerView.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

import SwiftUI
import SwiftData

struct GameContainerView: View {
    @Environment(SettingsManager.self) var settings: SettingsManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let existingSave: GameSave?
    
    @State private var coordinator: GameCoordinator?
    @State private var autoSaveTask: Task<Void, Never>?
    
    var body: some View {
        if let coordinator {
            let _ = print("🟡 GameContainerView body evaluated, coordinator[\(coordinator.id)], phase=\(coordinator.phase)")
            
            ZStack {
                G.bg.ignoresSafeArea()
                Scanlines()
                
                switch coordinator.phase {
                case .textScene:
                    TextSceneView(
                        coordinator: coordinator,
                        onExit: { handleExit() },
                        savedState: coordinator.savedTextSceneState
                    )
                    .transition(.opacity)
                    
                case .transitionToEncounter:
                    TransitionView(coordinator: coordinator)
                        .transition(.opacity)
                    
                case .encounter:
                    EncounterView(
                        coordinator: coordinator,
                        onExit: { handleExit() },
                        savedState: coordinator.savedEncounterState
                    )
                    .transition(.opacity)
                    
                case .epilogue:
                    EpilogueView(coordinator: coordinator, onExit: { handleExit() })
                        .transition(.opacity)
                }
                
                // Heart Animations Overlay
                GeometryReader { geo in
                    ZStack {
                        ForEach(coordinator.heartAnimations) { anim in
                            Image(systemName: "heart.fill")
                                .font(.system(size: anim.phase == 0 ? 10 : (anim.phase == 1 ? 40 : 20)))
                                .foregroundColor(.pink)
                                .shadow(color: .pink.opacity(0.5), radius: 8)
                                .opacity(anim.phase == 2 ? 0 : 1)
                                .position(
                                    anim.phase == 2
                                        ? CGPoint(x: geo.size.width - 40, y: geo.safeAreaInsets.top + 30) // top right profile pic
                                        : anim.startPoint
                                )
                                .id(anim.id)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            .coordinateSpace(name: "GameSpace")
            .animation(G.appear, value: coordinator.phase)
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .onChange(of: coordinator.phase) { oldPhase, newPhase in
                // Save when phase changes
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    saveGameState(coordinator)
                }
            }
            .onChange(of: coordinator.savedTextSceneState?.bubbles.count) { oldCount, newCount in
                // Save when text scene bubbles change
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    saveGameState(coordinator)
                }
            }
            .onChange(of: coordinator.savedEncounterState?.bubbles.count) { oldCount, newCount in
                // Save when encounter bubbles change
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    saveGameState(coordinator)
                }
            }
            .onAppear {
                // Start periodic auto-save every 5 seconds
                startAutoSave(coordinator)
            }
            .onDisappear {
                autoSaveTask?.cancel()
            }
        } else {
            Color.clear
                .onAppear {
                    if let save = existingSave {
                        coordinator = GameCoordinator(settings: settings, loadingFrom: save)
                    } else {
                        coordinator = GameCoordinator(settings: settings)
                    }
                }
        }
    }
    
    private func startAutoSave(_ coordinator: GameCoordinator) {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if !Task.isCancelled {
                    saveGameState(coordinator)
                }
            }
        }
    }
    
    private func handleExit() {
        autoSaveTask?.cancel()
        if let coordinator {
            saveGameState(coordinator)
        }
        dismiss()
    }
    
    private func saveGameState(_ coordinator: GameCoordinator) {
        let textNodeIndex = coordinator.savedTextSceneState?.nodeIndex ?? 0
        let textBubbles = coordinator.savedTextSceneState?.bubbles ?? []
        
        let encounterNodeIndex = coordinator.savedEncounterState?.nodeIndex ?? 0
        let encounterBubbles = coordinator.savedEncounterState?.bubbles ?? []
        
        let textBubblesJSON = try? JSONEncoder().encode(textBubbles)
        let encounterBubblesJSON = try? JSONEncoder().encode(encounterBubbles)
        
        // Delete old saves
        let descriptor = FetchDescriptor<GameSave>()
        if let oldSaves = try? modelContext.fetch(descriptor) {
            for save in oldSaves {
                modelContext.delete(save)
            }
        }
        
        let phaseString: String = {
            switch coordinator.phase {
            case .textScene: return "textScene"
            case .transitionToEncounter: return "transitionToEncounter"
            case .encounter: return "encounter"
            case .epilogue: return "epilogue"
            }
        }()
        
        let newSave = GameSave(
            phase: phaseString,
            totalScore: coordinator.totalScore,
            textSceneNodeIndex: textNodeIndex,
            encounterNodeIndex: encounterNodeIndex,
            textSceneBubblesJSON: textBubblesJSON,
            encounterBubblesJSON: encounterBubblesJSON
        )
        
        modelContext.insert(newSave)
        
        do {
            try modelContext.save()
            print("✅ Game saved: phase=\(phaseString), score=\(coordinator.totalScore), textNode=\(textNodeIndex), encounterNode=\(encounterNodeIndex)")
        } catch {
            print("❌ Failed to save game: \(error)")
        }
    }
}

// MARK: ─── Transition Screen ────────────────────────────────────────

struct TransitionView: View {
    let coordinator: GameCoordinator
    @State private var fadeIn = false
    @State private var btnIn = false
    
    var body: some View {
        let lang = coordinator.settings.language
        
        VStack(spacing: 28) {
            Spacer()
            
            VStack(spacing: 14) {
                Text(coordinator.encounterScene.location.l(lang))
                    .font(G.dynamicMono(.subheadline, .medium))
                    .tracking(4)
                    .foregroundColor(G.warm)
                
                Text(coordinator.encounterScene.atmosphere.l(lang))
                    .font(G.dynamicMono(.caption).italic())
                    .foregroundColor(G.text2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(fadeIn ? 1 : 0)
            
            Spacer()
            
            Button {
                coordinator.beginEncounter()
            } label: {
                Text("BEGIN ENCOUNTER")
                    .font(G.dynamicMono(.footnote, .medium))
                    .tracking(4)
                    .foregroundColor(G.warm)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(G.warm.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(G.warm.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(WarmBtnStyle())
            .opacity(btnIn ? 1 : 0)
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { fadeIn = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) { btnIn = true }
        }
    }
}

// MARK: ─── Epilogue Screen ──────────────────────────────────────────

struct EpilogueView: View {
    let coordinator: GameCoordinator
    let onExit: () -> Void
    
    @State private var visibleTexts: [String] = []
    @State private var showRestart = false
    @State private var epilogueTask: Task<Void, Never>?
    
    var body: some View {
        let lang = coordinator.settings.language
        let ending = coordinator.earnedEnding
        let tier = coordinator.endingTier
        
        // Use sage green like the original TextSceneView
        let accent: Color = G.sage
        let bubbleKind: BubbleKind = tier == "good" ? .endingGood : tier == "neutral" ? .endingNeutral : .endingBad
        
        VStack(spacing: 0) {
            TopBar(title: "ANDREAS", accent: accent, totalScore: coordinator.totalScore, onExit: onExit)
            Rectangle().fill(accent.opacity(0.12)).frame(height: 1)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        BubbleView(
                            bubble: ChatBubble(kind: .system, text: ending.postSceneLabel.l(lang)),
                            lang: lang
                        )
                        
                        ForEach(Array(visibleTexts.enumerated()), id: \.offset) { i, txt in
                            BubbleView(bubble: ChatBubble(kind: bubbleKind, text: txt), lang: lang)
                                .id(i)
                        }
                        
                        if showRestart {
                            VStack(spacing: 14) {
                                Text("score: \(coordinator.totalScore)")
                                    .font(G.dynamicMono(.caption2))
                                    .foregroundColor(G.dim)
                                
                                HStack(spacing: 14) {
                                    Button {
                                        epilogueTask?.cancel()
                                        coordinator.restart()
                                    } label: {
                                        Text("RESTART")
                                            .font(G.dynamicMono(.caption, .medium))
                                            .tracking(3)
                                            .foregroundColor(G.text2)
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 9)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .stroke(G.text2.opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                    
                                    Button(action: onExit) {
                                        Text("MENU")
                                            .font(G.dynamicMono(.caption, .medium))
                                            .tracking(3)
                                            .foregroundColor(accent)
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 9)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .stroke(accent.opacity(0.35), lineWidth: 1)
                                            )
                                    }
                                }
                                .buttonStyle(WarmBtnStyle())
                            }
                            .padding(.top, 10)
                            .id("restart_section")
                        }
                        
                        Color.clear.frame(height: 1).id("scroll_anchor")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: visibleTexts.count) {
                    scrollToAnchor(proxy)
                }
                .onChange(of: showRestart) { oldShow, newShow in
                    if newShow {
                        scrollToAnchor(proxy)
                    }
                }
            }
        }
        .environment(\.layoutDirection, lang.direction)
        .onAppear { startEpilogue() }
        .onDisappear { epilogueTask?.cancel() }
    }
    
    private func scrollToAnchor(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            proxy.scrollTo("scroll_anchor", anchor: .bottom)
        }
    }
    
    private func startEpilogue() {
        let lang = coordinator.settings.language
        let ending = coordinator.earnedEnding
        let pacing = coordinator.settings.pacing
        
        epilogueTask = Task { @MainActor in
            let introDelay: UInt64 = pacing == .fast ? 300_000_000 : 1_200_000_000
            try? await Task.sleep(nanoseconds: introDelay)
            
            for text in ending.finalTexts {
                let localized = text.l(lang)
                try? await Task.sleep(nanoseconds: pacing.typingDelayNs(charCount: localized.count))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    visibleTexts.append(localized)
                }
            }
            
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                showRestart = true 
            }
        }
    }
}
