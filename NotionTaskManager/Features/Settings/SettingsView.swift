import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    
    @State private var tokenInput: String = ""
    @State private var databaseIDInput: String = ""
    @State private var notionVersionInput: String = ""
    @State private var statusMessage: String?
    @State private var showingClearConfirm = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Credentials
                credentialsSection
                
                // API Settings
                apiSection
                
                // Actions
                actionsSection
                
                // Status
                if let statusMessage {
                    statusSection(message: statusMessage)
                }
                
                // Info
                infoSection
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .task(loadValues)
        .alert("トークンを削除", isPresented: $showingClearConfirm) {
            Button("削除", role: .destructive) {
                clearToken()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("保存されているNotionトークンを削除しますか？")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Notion連携")
                .font(.title2.weight(.bold))
            
            Text("NotionデータベースとアプリをAPIで接続します")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Credentials Section
    
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "認証情報", icon: "key.fill")
            
            VStack(spacing: 12) {
                // Token field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Integration Token")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        SecureField("secret_xxxxx...", text: $tokenInput)
                            .textContentType(.password)
                            .font(.system(size: 15))
                        
                        if !tokenInput.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                // Database ID field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Database ID")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $databaseIDInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 15, design: .monospaced))
                        
                        if !databaseIDInput.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                // Validation message
                if tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    databaseIDInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 12))
                        Text("TokenとDatabase IDは必須です")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - API Section
    
    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "API設定", icon: "gearshape.fill")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("API Version")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("2022-06-28", text: $notionVersionInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    )
                
                Text("Notionのドキュメントに記載されている最新の安定バージョンを使用してください")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Save button
            Button(action: save) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("設定を保存")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            // Clear button
            Button {
                showingClearConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("トークンを削除")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Status Section
    
    private func statusSection(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(statusColor)
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(statusColor.opacity(0.1))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: statusMessage)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "ヘルプ", icon: "questionmark.circle.fill")
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(title: "Integration Tokenの取得", description: "Notion設定 → 自分のコネクト → インテグレーションを作成")
                infoRow(title: "Database IDの確認", description: "データベースページのURLから取得（/で区切られた32文字）")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
    }
    
    private func infoRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch statusMessage {
        case "設定を保存しました": return "checkmark.circle.fill"
        case "トークンを削除しました": return "trash.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch statusMessage {
        case "設定を保存しました": return .green
        case "トークンを削除しました": return .orange
        default: return .red
        }
    }
    
    // MARK: - Actions
    
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
            statusMessage = "TokenとDatabase IDを入力してください"
            return
        }
        
        dependencies.credentialsStore.token = trimmedToken
        dependencies.settingsStore.databaseID = trimmedDBID
        if !trimmedVersion.isEmpty {
            dependencies.settingsStore.notionVersion = trimmedVersion
        }
        statusMessage = "設定を保存しました"
        
        // Clear status after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if statusMessage == "設定を保存しました" {
                withAnimation {
                    statusMessage = nil
                }
            }
        }
    }
    
    private func clearToken() {
        dependencies.credentialsStore.clear()
        tokenInput = ""
        statusMessage = "トークンを削除しました"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if statusMessage == "トークンを削除しました" {
                withAnimation {
                    statusMessage = nil
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppDependencies())
    }
}
