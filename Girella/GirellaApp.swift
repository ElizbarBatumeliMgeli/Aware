//
//  GirellaApp.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//

// GirellaApp.swift
// Girella — A Branching Narrative Game

import SwiftUI

@main
struct GirellaApp: App {
    @State private var settings = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environment(settings)
                .preferredColorScheme(.dark)
        }
    }
}
