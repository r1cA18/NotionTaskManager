import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    @State private var tokenInput: String = ""
    @State private var databaseIDInput: String = ""
    @State private var notionVersionInput: String = ""
    @State private var statusMessage: String?

    var body: some View {
        Form {
            credentialsSection
            apiSection
            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusColor)
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save", action: save)
            }
        }
        .task(loadValues)
    }

    private var credentialsSection: some View {
        Section("Notion Credentials") {
            SecureField("Integration Token", text: $tokenInput)
                .textContentType(.password)
            TextField("Database ID", text: $databaseIDInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                databaseIDInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Token and Database ID are required to sync.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button("Clear Token", role: .destructive) {
                dependencies.credentialsStore.clear()
                tokenInput = ""
                statusMessage = "Token cleared"
            }
        }
    }

    private var apiSection: some View {
        Section("Notion API") {
            TextField("API Version", text: $notionVersionInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Use the latest stable Notion API version as documented.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch statusMessage {
        case "Settings saved":
            return .green
        case "Token cleared":
            return .orange
        case "Please provide both token and database ID.":
            return .red
        default:
            return .secondary
        }
    }

    private func loadValues() {
        tokenInput = dependencies.credentialsStore.token
        databaseIDInput = dependencies.settingsStore.databaseID
        notionVersionInput = dependencies.settingsStore.notionVersion
    }

    private func save() {
        let trimmedToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDBID = databaseIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVersion = notionVersionInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedToken.isEmpty, !trimmedDBID.isEmpty else {
            statusMessage = "Please provide both token and database ID."
            return
        }

        dependencies.credentialsStore.token = trimmedToken
        dependencies.settingsStore.databaseID = trimmedDBID
        if !trimmedVersion.isEmpty {
            dependencies.settingsStore.notionVersion = trimmedVersion
        }
        statusMessage = "Settings saved"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppDependencies())
    }
}
