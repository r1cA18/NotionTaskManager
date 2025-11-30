import SwiftUI

struct CompletedCard: View {
    let model: TaskDisplayModel
    let onTap: () -> Void
    let tint: Color = TaskPalette.completedForeground
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(model.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .strikethrough(true, color: .secondary.opacity(0.5))
                
                if let memo = memoText {
                    Text(memo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 12) {
                    if let endTime = model.endTime {
                        Label(
                            endTime.formatted(date: .omitted, time: .shortened),
                            systemImage: "clock.badge.checkmark"
                        )
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    if let url = model.url, let label = model.bookmarkLabel {
                        Link(destination: url) {
                            Label(label, systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("関連リンクを開く")
                    }
                }
            }
            
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: onTap)
    }
    
    private var memoText: String? {
        let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    VStack(spacing: 12) {
        CompletedCard(
            model: TaskDisplayModel(task: TaskEntity(
                notionID: "1",
                name: "Completed task",
                status: .complete,
                timestamp: Date(),
                timeslot: .morning,
                endTime: Date(),
                priority: .fourStars,
                updatedAt: Date(),
                createdAt: Date()
            )),
            onTap: {}
        )
        
        CompletedCard(
            model: TaskDisplayModel(task: TaskEntity(
                notionID: "2",
                name: "Another completed task with a longer title",
                memo: "This is a memo for the task",
                status: .complete,
                timestamp: Date(),
                timeslot: .afternoon,
                endTime: Date().addingTimeInterval(-3600),
                priority: .twoStars,
                updatedAt: Date(),
                createdAt: Date()
            )),
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
