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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dateRange.dates, id: \.self) { date in
                    DateCell(
                        date: date,
                        isSelected: isSameDay(date, selectedDate)
                    )
                    .onTapGesture {
                        selectedDate = date
                        scrollPosition = date
                        onDateChanged(date)
                    }
                }
            }
            .padding(.horizontal, 20)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 80)
        .onChange(of: scrollPosition) { oldValue, newValue in
            if let newValue, !isSameDay(newValue, selectedDate) {
                selectedDate = newValue
                onDateChanged(newValue)
            }
        }
        .onAppear {
            scrollPosition = selectedDate.startOfDayInJST()
        }
    }

    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}

/// Individual date cell in the horizontal selector
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
        VStack(spacing: 4) {
            Text(weekdayFormatter.string(from: date))
                .font(.caption2)
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(dayFormatter.string(from: date))
                .font(.title3)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(width: 56, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday && !isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
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
