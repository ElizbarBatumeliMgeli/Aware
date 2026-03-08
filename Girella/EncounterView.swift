//
//  EncounterView.swift
//  Girella
//

import SwiftUI

struct EncounterView: View {
    let coordinator: GameCoordinator
    let onExit: () -> Void
    let savedState: (nodeIndex: Int, bubbles: [ChatBubble])?
    
    @State private var vm: EncounterVM?
    @State private var hasStarted = false
    
    private var viewModel: EncounterVM {
        if let vm { return vm }
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
                        ForEach(Array(viewModel.bubbles.enumerated()), id: \.element.id) { index, b in
                            let isLastInGroup = b.kind == .npc && (
                                index == viewModel.bubbles.count - 1 ||
                                viewModel.bubbles[index + 1].kind != .npc
                            )
                            let isTypingLast = viewModel.isAndreasTyping && (index == viewModel.bubbles.count - 1)

                            BubbleView(bubble: b, lang: lang, showProfileImage: isLastInGroup && !isTypingLast, isEncounter: true)
                                .id(b.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95, anchor: .leading).combined(with: .opacity),
                                    removal: .scale(scale: 0.95, anchor: .leading).combined(with: .opacity)
                                ))
                        }
                        
                        if viewModel.isThinking {
                            ThinkingDots()
                                .id("thinking_indicator")
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                        
                        if viewModel.isAndreasTyping {
                            AndreasTypingIndicator()
                                .id("andreas_typing_indicator")
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .leading).combined(with: .opacity),
                                    removal: .scale(scale: 0.95, anchor: .leading).combined(with: .opacity)
                                ))
                        }
                        
                        Color.clear.frame(height: 1).id("scroll_anchor")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .defaultScrollAnchor(.bottom)
                // ─── FIX: Dock the bottom bar right onto the ScrollView ───
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 8) {
                        Rectangle().fill(G.warm.opacity(0.1)).frame(height: 1)
                        
                        if viewModel.isPlayerTyping {
                            CenterTypingIndicator(text: "you are typing", color: G.playerBorder)
                                .padding(.vertical, 24)
                                .transition(.opacity)
                        } else if viewModel.choicesVisible && !viewModel.choices.isEmpty {
                            ForEach(viewModel.choices) { c in
                                ChoiceBtn(text: c.text, lang: lang) { viewModel.selectChoice(c) }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        } else {
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
                    .background(G.surface) // This will automatically fill the gap behind the home indicator!
                    .animation(.easeOut(duration: 0.3), value: viewModel.isThinking)
                    .animation(.easeOut(duration: 0.3), value: viewModel.isAndreasTyping)
                    .animation(.easeOut(duration: 0.3), value: viewModel.isPlayerTyping)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.choicesVisible)
                }
                .onChange(of: viewModel.bubbles.count) { scrollToAnchor(proxy) }
                .onChange(of: viewModel.isThinking) { _, new in if new { scrollToAnchor(proxy) } }
                .onChange(of: viewModel.isAndreasTyping) { _, new in if new { scrollToAnchor(proxy) } }
                .onChange(of: viewModel.choicesVisible) { _, new in if new { scrollToAnchor(proxy) } }
            }
        }
        .environment(\.layoutDirection, lang.direction)
        .onAppear {
            if vm == nil {
                vm = EncounterVM(
                    scene: coordinator.encounterScene,
                    settings: coordinator.settings,
                    coordinator: coordinator,
                    onPoints: { [weak coordinator = coordinator] p in coordinator?.addPoints(p) },
                    onFinish: { [weak coordinator = coordinator] in coordinator?.finishEncounter() }
                )
            }
            if !hasStarted {
                if let saved = savedState {
                    viewModel.loadState(nodeIndex: saved.nodeIndex, bubbles: saved.bubbles)
                } else {
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
