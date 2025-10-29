import SwiftUI

struct TodoCard: View {
    let model: TaskDisplayModel
    let tint: Color
    let onStart: () -> Void
    let onTrash: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                PriorityBadge(priority: model.priority)
            }

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
            if let memo = memoText {
                Text(memo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let url = model.url, let label = model.bookmarkLabel {
                Link(destination: url) {
                    Label(label, systemImage: "link")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("関連リンクを開く")
            }

            HStack(spacing: 12) {
                Button(action: onStart) {
                    Label("開始", systemImage: "play.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(model.status == .inProgress)

                Button(role: .destructive, action: onTrash) {
                    Image(systemName: "trash")
                        .padding(6)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("タスクを削除")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.6), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private var memoText: String? {
        let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
