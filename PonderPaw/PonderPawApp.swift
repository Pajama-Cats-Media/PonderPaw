//
//  PonderPawApp.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/6/25.
//

import SwiftUI
import SwiftData

@main
struct PonderPawApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var isLoggedIn = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Add your models here if needed
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
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
