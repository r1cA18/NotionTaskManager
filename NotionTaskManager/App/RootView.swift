import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.modelContext) private var modelContext
    @State private var repository: TaskRepository?
    @State private var syncService: TaskSyncService?
    @State private var isInitialized = false
    
    var body: some View {
        NavigationStack {
            Group {
                if dependencies.currentCredentials() == nil {
                    onboardingView
                } else if let repository, let syncService, isInitialized {
                    DateNavigationView(repository: repository, syncService: syncService)
                } else {
                    loadingView
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await initializeServices()
        }
    }
    
    private var onboardingView: some View {
        VStack(spacing: 24) {
            // App icon placeholder
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 8) {
                Text("Notion Task Manager")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Notionのタスクをシンプルに管理")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("設定からNotion Integration TokenとDatabase IDを追加して、同期を開始しましょう。")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            
            NavigationLink("設定を開く") {
                SettingsView()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            
            Text("読み込み中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func initializeServices() async {
        // Quick initialization on main actor
        await MainActor.run {
            let repo = TaskRepository(context: modelContext)
            repository = repo
            syncService = TaskSyncService(
                dependencies: dependencies,
                repository: repo,
                mapper: NotionTaskMapper()
            )
            isInitialized = true
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppDependencies())
        .modelContainer(for: TaskEntity.self, inMemory: true)
}
