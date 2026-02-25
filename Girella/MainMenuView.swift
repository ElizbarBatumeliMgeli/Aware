//
//  MainMenuView.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//

// MainMenuView.swift
// AWARE — Main Menu

import SwiftUI

struct MainMenuView: View {
    @Environment(SettingsManager.self) var settings: SettingsManager
    @State private var showGame = false
    @State private var showSettings = false
    @State private var titleIn = false
    @State private var btnsIn = false
    @State private var glow: Double = 0.3
    
    var body: some View {
        NavigationStack {
            ZStack {
                G.bg.ignoresSafeArea()
                Scanlines()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("AWARE")
                            .font(.system(.largeTitle, design: .monospaced, weight: .ultraLight))
                            .tracking(20)
                            .foregroundColor(G.warm)
                            .shadow(color: G.warm.opacity(glow), radius: 28)
                            .shadow(color: G.warm.opacity(glow * 0.3), radius: 50)
                        
                        Text("a branching narrative")
                            .font(G.dynamicMono(.caption))
                            .foregroundColor(G.text2)
                            .tracking(5)
                    }
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 10)
                    
                    Spacer()
                    
                    VStack(spacing: 14) {
                        MenuBtn(label: "PLAY", accent: G.warm) { showGame = true }
                        MenuBtn(label: "SETTINGS", accent: G.text2) { showSettings = true }
                    }
                    .opacity(btnsIn ? 1 : 0)
                    .padding(.horizontal, 48)
                    .padding(.bottom, 80)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { titleIn = true }
                withAnimation(.easeOut(duration: 0.7).delay(0.4)) { btnsIn = true }
                withAnimation(G.pulse) { glow = 0.55 }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showGame) {
                GameContainerView()
                    .environment(settings)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(settings)
            }
        }
    }
}

// MARK: - Menu Button

private struct MenuBtn: View {
    let label: String
    let accent: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(G.dynamicMono(.subheadline, .medium))
                .tracking(6)
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(WarmBtnStyle())
    }
}

