import SwiftUI

/// Large date display at the top of the screen (tappable to open calendar)
struct DateHeaderView: View {
    let date: Date
    let onTap: () -> Void
    let onTodayTap: (() -> Void)?
    
    @State private var isPressed = false
    
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .tokyo
        return cal
    }
    
    init(date: Date, onTap: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
        self.date = date
        self.onTap = onTap
        self.onTodayTap = onLongPress
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.timeZone = .tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private var isToday: Bool {
        Self.calendar.isDateInToday(date)
    }
    
    private var relativeLabel: String? {
        if Self.calendar.isDateInToday(date) {
            return "今日"
        } else if Self.calendar.isDateInYesterday(date) {
            return "昨日"
        } else if Self.calendar.isDateInTomorrow(date) {
            return "明日"
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Calendar button
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let label = relativeLabel {
                            Text(label)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(formattedDate)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2), value: isPressed)
            
            // Today button (visible when not on today)
            if !isToday, let onTodayTap {
                Button(action: onTodayTap) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14, weight: .semibold))
                        Text("今日")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isToday)
    }
}

#Preview {
    VStack {
        DateHeaderView(
            date: Date(),
            onTap: {},
            onLongPress: {}
        )
        DateHeaderView(
            date: Date().addingTimeInterval(86400),
            onTap: {},
            onLongPress: {}
        )
        Spacer()
    }
}
