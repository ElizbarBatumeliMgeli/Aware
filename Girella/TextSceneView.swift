//
//  TextSceneView.swift
//  Girella
//
//  Created by Elizbar Kheladze on 23/02/26.
//

// TextSceneView.swift
// AWARE — Text Message Thread UI
// FIX: Messages remain visible above the pinned choice panel at the bottom.

import SwiftUI

struct TextSceneView: View {
    let coordinator: GameCoordinator
    let onExit: () -> Void
    
    @State private var vm: TextSceneVM?
    @State private var hasStarted = false
    
    private var viewModel: TextSceneVM {
        if let vm {
            return vm
        }
        // Fallback - should not happen
        return TextSceneVM(
            scene: coordinator.textScene,
            settings: coordinator.settings,
            onPoints: { _ in },
            onTransition: {}
        )
    }
    
    var body: some View {
        let lang = coordinator.settings.language
        
        VStack(spacing: 0) {
            // Top bar
            TopBar(title: "ANDREAS", accent: G.sage, onExit: onExit)
            Rectangle().fill(G.sage.opacity(0.12)).frame(height: 1)
            
            // ─── Chat feed (fills all space above choices) ───
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.bubbles) { b in
                            BubbleView(bubble: b, lang: lang)
                                .id(b.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .leading)
                                        .combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        if viewModel.isTyping {
                            TypingDots(label: "andreas is typing")
                                .id("typing_indicator")
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                        
                        // Invisible anchor to scroll to — sits below all content
                        Color.clear
                            .frame(height: 1)
                            .id("scroll_anchor")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: viewModel.bubbles.count) {
                    scrollToAnchor(proxy)
                }
                .onChange(of: viewModel.isTyping) { oldTyping, newTyping in
                    if newTyping { scrollToAnchor(proxy) }
                }
                .onChange(of: viewModel.choicesVisible) { oldVisible, newVisible in
                    if newVisible {
                        // When choices appear, scroll so messages are above them
                        scrollToAnchor(proxy)
                    }
                }
            }
            
            // ─── Choice panel pinned at bottom ───
            if viewModel.choicesVisible && !viewModel.choices.isEmpty {
                ChoicePanel(choices: viewModel.choices, lang: lang) { choice in
                    viewModel.selectChoice(choice)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // ─── Transition button ───
            if viewModel.showTransitionButton {
                VStack(spacing: 0) {
                    Rectangle().fill(G.sage.opacity(0.1)).frame(height: 1)
                    
                    Button {
                        viewModel.triggerTransition()
                    } label: {
                        Text("BEGIN ENCOUNTER")
                            .font(G.dynamicMono(.footnote, .medium))
                            .tracking(4)
                            .foregroundColor(G.sage)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(G.sage.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(G.sage.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(WarmBtnStyle())
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }
                .background(G.surface.ignoresSafeArea(edges: .bottom))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.choicesVisible)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showTransitionButton)
        .environment(\.layoutDirection, lang.direction)
        .onAppear {
            if vm == nil {
                vm = TextSceneVM(
                    scene: coordinator.textScene,
                    settings: coordinator.settings,
                    onPoints: { [coordinator] p in 
                        coordinator.addPoints(p) 
                    },
                    onTransition: { [coordinator] in 
                        print("🟣 TextSceneView: onTransition called")
                        coordinator.advanceToTransition() 
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
