import SwiftUI

struct CompletedCard: View {
    let model: TaskDisplayModel
    let onTap: () -> Void
    let tint: Color = TaskPalette.completedForeground

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.title)
                .font(.body)
                .foregroundStyle(.primary)
            if let memo = memoText {
                Text(memo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let url = model.url, let label = model.bookmarkLabel {
                Link(destination: url) {
                    Label(label, systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("関連リンクを開く")
            }
            if let endTime = model.endTime {
                Label(
                    endTime.formatted(date: .omitted, time: .shortened), systemImage: "checkmark.seal.fill"
                )
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
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
