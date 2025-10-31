import SwiftUI

/// Large date display at the top of the screen (tappable to open calendar)
struct DateHeaderView: View {
    let date: Date
    let onTap: () -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.timeZone = .tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(formattedDate)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 4, y: 4)
                    .shadow(color: Color.white.opacity(0.7), radius: 8, x: -4, y: -4)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("日付を選択: \(formattedDate)")
    }
}

#Preview {
    VStack {
        DateHeaderView(date: Date(), onTap: {})
        Spacer()
    }
}
