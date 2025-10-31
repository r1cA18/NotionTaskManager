import SwiftUI

/// Large date display at the top of the screen (tappable to open calendar)
struct DateHeaderView: View {
  let date: Date
  let onTap: () -> Void
  let onLongPress: (() -> Void)?

  init(date: Date, onTap: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
    self.date = date
    self.onTap = onTap
    self.onLongPress = onLongPress
  }

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
      .padding(.vertical, 16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(.systemGroupedBackground))
          .shadow(color: Color.black.opacity(0.15), radius: 8, x: 4, y: 4)
          .shadow(color: Color.white.opacity(0.7), radius: 8, x: -4, y: -4)
      )
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 12)  // DateHeaderViewとDateSelectorViewの間隔
    }
    .buttonStyle(.plain)
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 0.5)
        .onEnded { _ in
          onLongPress?()
        }
    )
    .accessibilityLabel("日付を選択: \(formattedDate)")
  }
}

#Preview {
  VStack {
    DateHeaderView(date: Date(), onTap: {})
    Spacer()
  }
}
