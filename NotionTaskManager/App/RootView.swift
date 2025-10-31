import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.modelContext) private var modelContext
    @State private var repository: TaskRepository?
    @State private var syncService: TaskSyncService?

    var body: some View {
        NavigationStack {
            Group {
                if dependencies.currentCredentials() == nil {
                    VStack(spacing: 16) {
                        Text("Notion Task Manager")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Add your Notion integration token and database ID in Settings to start syncing tasks.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        navigationButton
                    }
                    .padding()
                } else if let repository, let syncService {
                    DateNavigationView(repository: repository, syncService: syncService)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Settings") {
                        SettingsView()
                    }
                }
            }
        }
        .task {
            await MainActor.run {
                let repo = TaskRepository(context: modelContext)
                repository = repo
                syncService = TaskSyncService(
                    dependencies: dependencies,
                    repository: repo,
                    mapper: NotionTaskMapper()
                )
            }
        }
    }

    private var navigationButton: some View {
        NavigationLink("Settings") {
            SettingsView()
        }
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    RootView()
        .environmentObject(AppDependencies())
        .modelContainer(for: TaskEntity.self, inMemory: true)
}
