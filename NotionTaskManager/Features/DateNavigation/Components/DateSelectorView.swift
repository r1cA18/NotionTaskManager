import SwiftUI

/// Horizontal scrollable date selector with snap-to-center behavior
struct DateSelectorView: View {
    @Binding var selectedDate: Date
    let onDateChanged: (Date) -> Void

    @State private var dateRange: DateRange
    @State private var scrollPosition: Date?

    init(selectedDate: Binding<Date>, onDateChanged: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self.onDateChanged = onDateChanged
        self._dateRange = State(initialValue: DateRange(centerDate: selectedDate.wrappedValue))
        self._scrollPosition = State(initialValue: selectedDate.wrappedValue.startOfDayInJST())
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 左端のパディング（画面幅の半分 - セル幅の半分）
                    Spacer()
                        .frame(width: (geometry.size.width - 48) / 2)

                    ForEach(dateRange.dates, id: \.self) { date in
                        DateCell(
                            date: date,
                            isSelected: isSameDay(date, selectedDate)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedDate = date
                                scrollPosition = date
                            }
                            onDateChanged(date)
                        }
                    }

                    // 右端のパディング（画面幅の半分 - セル幅の半分）
                    Spacer()
                        .frame(width: (geometry.size.width - 48) / 2)
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: 80)
        .onChange(of: scrollPosition) { oldValue, newValue in
            if let newValue, !isSameDay(newValue, selectedDate) {
                selectedDate = newValue
                onDateChanged(newValue)
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            if !isSameDay(oldValue, newValue) {
                withAnimation(.spring(response: 0.3)) {
                    scrollPosition = newValue.startOfDayInJST()
                }
            }
        }
        .task {
            // Ensure scroll position is set on first appearance without animation
            if scrollPosition == nil {
                scrollPosition = selectedDate.startOfDayInJST()
            }
        }
    }

    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}

/// Individual date cell in the horizontal selector (circular design)
struct DateCell: View {
    let date: Date
    let isSelected: Bool

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.timeZone = .tokyo
        return formatter
    }

    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.timeZone = .tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }

    private var isToday: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(weekdayFormatter.string(from: date))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(dayFormatter.string(from: date))
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(width: 48, height: 48)
        .background(
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                } else if isToday {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                } else {
                    // Neumorphism effect
                    Circle()
                        .fill(Color(.systemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 2, y: 2)
                        .shadow(color: Color.white.opacity(0.7), radius: 3, x: -2, y: -2)
                }
            }
        )
    }
}

#Preview {
    VStack {
        DateSelectorView(
            selectedDate: .constant(Date()),
            onDateChanged: { _ in }
        )
        Spacer()
    }
}
