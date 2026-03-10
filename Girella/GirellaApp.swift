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

// Re-enable the interactive pop gesture (swipe to go back)
// when the native navigation bar back button is hidden.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
