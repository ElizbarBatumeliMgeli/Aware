//
//  EncounterView.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

import SwiftUI

struct EncounterView: View {
    let coordinator: GameCoordinator
    let onExit: () -> Void
    let savedState: (nodeIndex: Int, bubbles: [ChatBubble])?  // NEW: Optional saved state
    
    @State private var vm: EncounterVM?
    @State private var hasStarted = false
    
    private var viewModel: EncounterVM {
        if let vm {
            return vm
        }
        // Fallback - should not happen
        return EncounterVM(
            scene: coordinator.encounterScene,
            settings: coordinator.settings,
            coordinator: coordinator,
            onPoints: { _ in },
            onFinish: {}
        )
    }
    
    var body: some View {
        let lang = coordinator.settings.language
        
        VStack(spacing: 0) {
            TopBar(title: "ENCOUNTER", accent: G.warm, onExit: onExit)
            Rectangle().fill(G.warm.opacity(0.12)).frame(height: 1)
            
            // ─── Narrative feed ───
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.bubbles) { b in
                            BubbleView(bubble: b, lang: lang)
                                .id(b.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .leading)
                                        .combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        if viewModel.isThinking {
                            ThinkingDots()
                                .id("thinking_indicator")
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                        
                        Color.clear.frame(height: 1).id("scroll_anchor")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: viewModel.bubbles.count) {
                    scrollToAnchor(proxy)
                }
                .onChange(of: viewModel.isThinking) { oldThinking, newThinking in
                    if newThinking { scrollToAnchor(proxy) }
                }
                .onChange(of: viewModel.choicesVisible) { oldVisible, newVisible in
                    if newVisible { scrollToAnchor(proxy) }
                }
            }
            
            // ─── Choices pinned at bottom (always present) ───
            VStack(spacing: 8) {
                Rectangle().fill(G.warm.opacity(0.1)).frame(height: 1)
                
                if viewModel.isPlayerTyping {
                    // Show player typing indicator
                    PlayerTypingDots()
                        .padding(.vertical, 24)
                        .transition(.opacity)
                } else if viewModel.choicesVisible && !viewModel.choices.isEmpty {
                    ForEach(viewModel.choices) { c in
                        ChoiceBtn(text: c.text, lang: lang) { 
                            viewModel.selectChoice(c) 
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                } else {
                    // Show game name when no choices available
                    Text("GIRELLA")
                        .font(G.dynamicMono(.caption2, .medium))
                        .tracking(4)
                        .foregroundColor(G.dim.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(G.surface.ignoresSafeArea(edges: .bottom))
            .frame(minHeight: 100)
        }
        .environment(\.layoutDirection, lang.direction)
        .onAppear {
            if vm == nil {
                vm = EncounterVM(
                    scene: coordinator.encounterScene,
                    settings: coordinator.settings,
                    coordinator: coordinator,
                    onPoints: { [weak coordinator = coordinator] p in 
                        coordinator?.addPoints(p) 
                    },
                    onFinish: { [weak coordinator = coordinator] in 
                        coordinator?.finishEncounter() 
                    }
                )
            }
            if !hasStarted {
                if let saved = savedState {
                    // Load from save
                    viewModel.loadState(nodeIndex: saved.nodeIndex, bubbles: saved.bubbles)
                } else {
                    // Start fresh
                    viewModel.start()
                }
                hasStarted = true
            }
        }
    }
    
    private func scrollToAnchor(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            proxy.scrollTo("scroll_anchor", anchor: .bottom)
        }
    }
}
