//
//  TextSceneView.swift
//  Girella
//

import SwiftUI

struct TextSceneView: View {
    let coordinator: GameCoordinator
    let onExit: () -> Void
    
    // NEW: Tuple updated to include unlockDate
    let savedState: (nodeIndex: Int, bubbles: [ChatBubble], unlockDate: Date?)?
    
    @State private var vm: TextSceneVM?
    @State private var hasStarted = false
    
    private var viewModel: TextSceneVM {
        if let vm { return vm }
        return TextSceneVM(
            scene: coordinator.textScene,
            settings: coordinator.settings,
            coordinator: coordinator,
            onPoints: { _ in },
            onTransition: {}
        )
    }
    
    var body: some View {
        let lang = coordinator.settings.language
        
        VStack(spacing: 0) {
            TopBar(title: "ANDREAS", accent: G.sage, onExit: onExit)
            Rectangle().fill(G.sage.opacity(0.12)).frame(height: 1)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(viewModel.bubbles.enumerated()), id: \.element.id) { index, b in
                            let isLastInGroup = b.kind == .npc && (
                                index == viewModel.bubbles.count - 1 ||
                                viewModel.bubbles[index + 1].kind != .npc
                            )
                            
                            BubbleView(bubble: b, lang: lang, showProfileImage: isLastInGroup)
                                .id(b.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        if viewModel.isTyping {
                            AndreasTypingIndicator()
                                .id("andreas_typing_indicator")
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        Color.clear.frame(height: 1).id("scroll_anchor")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.bottom)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        // ─── BOTTOM BAR DOCK ───
                        VStack(spacing: 8) {
                            Rectangle().fill(G.sage.opacity(0.1)).frame(height: 1)
                            
                            // ─── NEW: WAIT INDICATOR ───
                            if viewModel.isWaiting {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                    Text(viewModel.waitMessage ?? "waiting...")
                                }
                                .font(G.dynamicMono(.caption2, .medium))
                                .foregroundColor(G.dim)
                                .padding(.vertical, 24)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                
                            } else if viewModel.isPlayerTyping {
                                CenterTypingIndicator(text: "you are typing", color: G.playerBorder)
                                    .padding(.vertical, 24)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                
                            } else if viewModel.choicesVisible && !viewModel.choices.isEmpty {
                                ForEach(viewModel.choices) { c in
                                    ChoiceBtn(text: c.text, lang: lang) { viewModel.selectChoice(c) }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            } else {
                                Text("Aware")
                                    .font(G.dynamicMono(.caption2, .medium))
                                    .tracking(4)
                                    .foregroundColor(G.dim.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        
                        // Transition button
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
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .background(G.surface)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isWaiting)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isTyping)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isPlayerTyping)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.choicesVisible)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showTransitionButton)
                }
                .onChange(of: viewModel.bubbles.count) { scrollToAnchor(proxy) }
                .onChange(of: viewModel.isTyping) { _, newTyping in if newTyping { scrollToAnchor(proxy) } }
                .onChange(of: viewModel.choicesVisible) { _, newVisible in if newVisible { scrollToAnchor(proxy) } }
            }
        }
        .environment(\.layoutDirection, lang.direction)
        .onAppear {
            if vm == nil {
                vm = TextSceneVM(
                    scene: coordinator.textScene,
                    settings: coordinator.settings,
                    coordinator: coordinator,
                    onPoints: { [coordinator] p in coordinator.addPoints(p) },
                    onTransition: { [coordinator] in coordinator.advanceToTransition() }
                )
            }
            if !hasStarted {
                if let saved = savedState {
                    // NEW: Pass the unlock date when restoring save!
                    viewModel.loadState(nodeIndex: saved.nodeIndex, bubbles: saved.bubbles, unlockDate: saved.unlockDate)
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
