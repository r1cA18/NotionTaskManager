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
    // Initialize dateRange centered around Today to ensure Today is visible
    let today = Date.todayInJST()
    self._dateRange = State(initialValue: DateRange(centerDate: today))
    self._scrollPosition = State(initialValue: today)
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
    .frame(height: 60)  // DateCell(48) + padding(6*2) = 60
    .padding(.bottom, 6)  // DateSelectorViewとメインビューの間隔
    .onChange(of: scrollPosition) { oldValue, newValue in
      // スワイプ終了時に最も近い日付にスナップ
      if let newValue, !isSameDay(newValue, selectedDate) {
        // 最も近い日付を見つける
        let closestDate = findClosestDate(to: newValue)
        if !isSameDay(closestDate, selectedDate) {
          // selectedDateを更新すると、onChange(of: selectedDate)が呼ばれてscrollPositionが更新される
          selectedDate = closestDate
          onDateChanged(closestDate)
        }
      }
    }
    .onChange(of: selectedDate) { oldValue, newValue in
      if !isSameDay(oldValue, newValue) {
        // Update dateRange if the selected date is far from center
        let centerDate = dateRange.centerDate.startOfDayInJST()
        let newDateStartOfDay = newValue.startOfDayInJST()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        let daysDifference = abs(
          calendar.dateComponents([.day], from: centerDate, to: newDateStartOfDay).day ?? 0)

        // If selected date is more than 10 days away from center, update range
        if daysDifference > 10 {
          dateRange = DateRange(centerDate: newDateStartOfDay)
        }

        withAnimation(.spring(response: 0.3)) {
          scrollPosition = newDateStartOfDay
        }
      }
    }
    .onAppear {
      // Ensure scroll position is set to Today on first appearance
      let today = Date.todayInJST()

      // Update dateRange to center around Today if it's not already
      if !dateRange.dates.contains(where: { isSameDay($0, today) }) {
        dateRange = DateRange(centerDate: today)
      }

      // Set scroll position to Today without animation
      scrollPosition = today
    }
    .task {
      // Ensure scroll position is set on first appearance without animation
      let today = Date.todayInJST()

      if scrollPosition == nil || !isSameDay(scrollPosition ?? Date(), today) {
        scrollPosition = today
      }
    }
  }

  private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .tokyo
    return calendar.isDate(date1, inSameDayAs: date2)
  }

  /// 指定された日付に最も近い日付を見つける
  private func findClosestDate(to date: Date) -> Date {
    let targetStartOfDay = date.startOfDayInJST()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .tokyo

    // dateRange内の最も近い日付を見つける
    var closestDate = dateRange.dates.first ?? targetStartOfDay
    var minDifference = TimeInterval.greatestFiniteMagnitude

    for rangeDate in dateRange.dates {
      let difference = abs(targetStartOfDay.timeIntervalSince(rangeDate.startOfDayInJST()))
      if difference < minDifference {
        minDifference = difference
        closestDate = rangeDate
      }
    }

    return closestDate
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
    .padding(6)  // シャドウが切れないようにパディングを追加
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
