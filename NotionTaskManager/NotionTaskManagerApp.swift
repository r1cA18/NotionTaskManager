//
//  NotionTaskManagerApp.swift
//  NotionTaskManager
//
//  Created by Yamaguchi Ryo on 2025/10/09.
//

import SwiftUI
import SwiftData

@main
struct NotionTaskManagerApp: App {
    @StateObject private var dependencies = AppDependencies()

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: TaskEntity.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencies)
                .modelContainer(sharedModelContainer)
        }
    }
}
