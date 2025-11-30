import SwiftUI

struct TodoCard: View {
    let model: TaskDisplayModel
    let tint: Color
    var isSyncing: Bool = false
    let onStart: () -> Void
    let onTrash: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row with priority badge and sync indicator
            HStack(alignment: .firstTextBaseline) {
                Text(model.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .transition(.opacity)
                }
                
                PriorityBadge(priority: model.priority)
            }
            
            // Metadata row
            HStack(spacing: 8) {
                if let timestamp = model.timestamp {
                    Label(timestamp.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label(model.timeslotLabel, systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Memo preview
            if let memo = memoText {
                Text(memo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            // Bookmark link
            if let url = model.url, let label = model.bookmarkLabel {
                Link(destination: url) {
                    Label(label, systemImage: "link")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("関連リンクを開く")
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onStart) {
                    HStack(spacing: 6) {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("開始")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(model.status == .inProgress || isSyncing)
                
                Button(role: .destructive, action: onTrash) {
                    Image(systemName: "trash")
                        .padding(6)
                }
                .buttonStyle(.borderless)
                .disabled(isSyncing)
                .accessibilityLabel("タスクを削除")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(isSyncing ? 0.3 : 0.6), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
        .opacity(isSyncing ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSyncing)
    }
    
    private var memoText: String? {
        let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    VStack(spacing: 16) {
        TodoCard(
            model: TaskDisplayModel(task: TaskEntity(
                notionID: "1",
                name: "Sample Task",
                status: .toDo,
                timestamp: Date(),
                timeslot: .morning,
                priority: .fourStars,
                updatedAt: Date(),
                createdAt: Date()
            )),
            tint: .blue,
            isSyncing: false,
            onStart: {},
            onTrash: {},
            onTap: {}
        )
        
        TodoCard(
            model: TaskDisplayModel(task: TaskEntity(
                notionID: "2",
                name: "Syncing Task",
                status: .toDo,
                timestamp: Date(),
                timeslot: .afternoon,
                priority: .twoStars,
                updatedAt: Date(),
                createdAt: Date()
            )),
            tint: .orange,
            isSyncing: true,
            onStart: {},
            onTrash: {},
            onTap: {}
        )
    }
    .padding()
}
