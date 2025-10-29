import SwiftUI

struct InProgressBar: View {
    let model: TaskDisplayModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 4) {
                Text("In Progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Label(model.timeslotLabel, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let startTime = model.startTime {
                        Label(
                            startTime.formatted(date: .omitted, time: .shortened),
                            systemImage: "clock.arrow.circlepath"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
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
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("関連リンクを開く")
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TaskPalette.tint(for: model.timeslot).opacity(0.6), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var memoText: String? {
        let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
