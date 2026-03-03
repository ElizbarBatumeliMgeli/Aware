//
//  GirellaApp.swift
//  Girella
//
//  Created by Elizbar Kheladze on 22/02/26.
//

import SwiftUI
import SwiftData

@main
struct GirellaApp: App {
    @State private var settings = SettingsManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            GameSave.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environment(settings)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
