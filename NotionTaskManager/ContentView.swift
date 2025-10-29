//
//  ContentView.swift
//  NotionTaskManager
//
//  Created by Yamaguchi Ryo on 2025/10/09.
//

import SwiftUI
import Combine
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var repository: TaskRepository

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.full")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Today view under construction")
                .font(.headline)
            Button("Reload Scopes") {
                Task {
                    _ = try? repository.fetchTasks(for: .todayTodo, on: Date())
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TaskEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let repository = TaskRepository(context: context)
    ContentView()
        .environmentObject(repository)
}
