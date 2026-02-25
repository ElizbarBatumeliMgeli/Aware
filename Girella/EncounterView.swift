//
//  EncounterView.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

// EncounterView.swift
// AWARE — In-Person Encounter UI

import SwiftUI

struct EncounterView: View {
    let coordinator: GameCoordinator
    let onExit: () -> Void
    
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
            
            // ─── Choices pinned at bottom ───
            if viewModel.choicesVisible && !viewModel.choices.isEmpty {
                ChoicePanel(choices: viewModel.choices, lang: lang) { choice in
                    viewModel.selectChoice(choice)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.choicesVisible)
        .environment(\.layoutDirection, lang.direction)
        .onAppear {
            if vm == nil {
                vm = EncounterVM(
                    scene: coordinator.encounterScene,
                    settings: coordinator.settings,
                    onPoints: { [weak coordinator = coordinator] p in 
                        coordinator?.addPoints(p) 
                    },
                    onFinish: { [weak coordinator = coordinator] in 
                        coordinator?.finishEncounter() 
                    }
                )
            }
            if !hasStarted {
                viewModel.start()
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
