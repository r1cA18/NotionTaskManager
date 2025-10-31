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
            .background(Color(.systemBackground))
        }
        .accessibilityLabel("日付を選択: \(formattedDate)")
    }
}

#Preview {
    VStack {
        DateHeaderView(date: Date(), onTap: {})
        Spacer()
    }
}
