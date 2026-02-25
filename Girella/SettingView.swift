//
//  SettingView.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//

// SettingsView.swift
// AWARE — Settings

import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            G.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(G.dynamicMono(.body, .medium))
                        .tracking(5)
                        .foregroundColor(G.warm)
                    Spacer()
                    Button { dismiss() } label: {
                        Text("CLOSE")
                            .font(G.dynamicMono(.caption2, .medium))
                            .tracking(2)
                            .foregroundColor(G.text2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(G.text2.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
                
                Rectangle().fill(G.warm.opacity(0.12)).frame(height: 1).padding(.horizontal, 24)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        SettingsGroup(title: "LANGUAGE") {
                            ForEach(AppLanguage.allCases) { lang in
                                RadioRow(label: lang.label, on: settings.language == lang) {
                                    withAnimation(.easeOut(duration: 0.15)) { settings.language = lang }
                                }
                            }
                        }
                        
                        SettingsGroup(title: "MESSAGE PACING") {
                            ForEach(Pacing.allCases) { p in
                                RadioRow(label: p.label, on: settings.pacing == p) {
                                    withAnimation(.easeOut(duration: 0.15)) { settings.pacing = p }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ABOUT")
                                .font(G.dynamicMono(.caption2, .semibold))
                                .tracking(3)
                                .foregroundColor(G.text2)
                            Text("AWARE is a narrative experience about eating disorders. Characters are fictional; the feelings are real.")
                                .font(G.dynamicMono(.caption))
                                .foregroundColor(G.text2)
                                .lineSpacing(4)
                            Text("If you or someone you know is struggling, please reach out to a professional.")
                                .font(G.dynamicMono(.caption))
                                .foregroundColor(G.rose)
                                .lineSpacing(4)
                                .padding(.top, 4)
                        }
                    }
                    .padding(24)
                    .padding(.top, 8)
                }
            }
        }
        .presentationBackground(G.bg)
    }
}

// MARK: - Section

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(G.dynamicMono(.caption2, .semibold))
                .tracking(3)
                .foregroundColor(G.text2)
            VStack(spacing: 6) { content() }
        }
    }
}

// MARK: - Radio Row

private struct RadioRow: View {
    let label: String
    let on: Bool
    let tap: () -> Void
    
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(on ? G.warm : G.text2.opacity(0.5), lineWidth: 1)
                        .frame(width: 14, height: 14)
                    if on {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(G.warm)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(label)
                    .font(G.dynamicMono(.subheadline))
                    .foregroundColor(on ? G.text1 : G.text2)
                Spacer()
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? G.surfaceLit : .clear))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(on ? G.warm.opacity(0.2) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
