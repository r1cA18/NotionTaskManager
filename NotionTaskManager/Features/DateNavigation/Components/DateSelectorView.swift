import SwiftUI
import Combine

/// Horizontal scrollable date selector with Liquid Glass design
struct DateSelectorView: View {
    @Binding var selectedDate: Date
    let onDateChanged: (Date) -> Void
    
    @State private var monthRange: MonthDateRange
    @State private var scrollPosition: Date?
    @State private var debounceTask: Task<Void, Never>?
    
    @Namespace private var animation
    
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .tokyo
        return cal
    }
    
    init(selectedDate: Binding<Date>, onDateChanged: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self.onDateChanged = onDateChanged
        let today = Date.todayInJST()
        self._monthRange = State(initialValue: MonthDateRange(containing: today))
        self._scrollPosition = State(initialValue: today)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            monthNavigation
            
            // Date scroll
            dateScrollView
        }
    }
    
    // MARK: - Month Navigation
    
    private var monthNavigation: some View {
        HStack(spacing: 0) {
            // Previous month
            Button {
                navigateMonth(delta: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Month title
            Text(monthRange.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Next month
            Button {
                navigateMonth(delta: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Date Scroll View
    
    private var dateScrollView: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Left padding
                    Spacer()
                        .frame(width: (geometry.size.width - 56) / 2)
                    
                    ForEach(monthRange.dates, id: \.self) { date in
                        DateCell(
                            date: date,
                            isSelected: isSameDay(date, selectedDate),
                            namespace: animation
                        )
                        .onTapGesture {
                            selectDate(date)
                        }
                    }
                    
                    // Right padding
                    Spacer()
                        .frame(width: (geometry.size.width - 56) / 2)
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: scrollPosition) { oldValue, newValue in
                handleScrollChange(newValue)
            }
        }
        .frame(height: 72)
        .onChange(of: selectedDate) { oldValue, newValue in
            handleSelectedDateChange(oldValue, newValue)
        }
        .onAppear {
            setupInitialPosition()
        }
    }
    
    // MARK: - Actions
    
    private func navigateMonth(delta: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            monthRange = delta < 0 ? monthRange.previousMonth : monthRange.nextMonth
            if let firstDay = monthRange.dates.first {
                selectedDate = firstDay
                scrollPosition = firstDay
                onDateChanged(firstDay)
            }
        }
    }
    
    private func selectDate(_ date: Date) {
        debounceTask?.cancel()
        
        let normalizedDate = date.startOfDayInJST()
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            selectedDate = normalizedDate
            scrollPosition = normalizedDate
        }
        
        onDateChanged(normalizedDate)
    }
    
    private func handleScrollChange(_ newValue: Date?) {
        guard let newValue else { return }
        
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
            guard !Task.isCancelled else { return }
            
            let closestDate = findClosestDate(to: newValue)
            if !isSameDay(closestDate, selectedDate) {
                selectedDate = closestDate
                onDateChanged(closestDate)
            }
        }
    }
    
    private func handleSelectedDateChange(_ oldValue: Date, _ newValue: Date) {
        guard !isSameDay(oldValue, newValue) else { return }
        
        if !monthRange.contains(newValue) {
            withAnimation(.spring(response: 0.3)) {
                monthRange = MonthDateRange(containing: newValue)
            }
        }
        
        if monthRange.contains(newValue) {
            scrollPosition = newValue.startOfDayInJST()
        }
    }
    
    private func setupInitialPosition() {
        let today = Date.todayInJST()
        if !monthRange.contains(today) {
            monthRange = MonthDateRange(containing: today)
        }
        scrollPosition = today
    }
    
    private func findClosestDate(to targetDate: Date) -> Date {
        let targetStart = targetDate.startOfDayInJST()
        var closestDate = monthRange.dates.first ?? targetStart
        var minDifference = TimeInterval.greatestFiniteMagnitude
        
        for date in monthRange.dates {
            let difference = abs(targetStart.timeIntervalSince(date.startOfDayInJST()))
            if difference < minDifference {
                minDifference = difference
                closestDate = date
            }
        }
        
        return closestDate.startOfDayInJST()
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Self.calendar.isDate(date1, inSameDayAs: date2)
    }
}

// MARK: - Date Cell

struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let namespace: Namespace.ID
    
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .tokyo
        return cal
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.timeZone = .tokyo
        return formatter.string(from: date)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.timeZone = .tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private var isToday: Bool {
        Self.calendar.isDateInToday(date)
    }
    
    private var isWeekend: Bool {
        let weekday = Self.calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(weekdayString)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textColor.opacity(0.8))
            
            Text(dayNumber)
                .font(.system(size: 18, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(width: 56, height: 56)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 0 : (isToday ? 2 : 0.5))
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: isSelected ? 4 : 2
        )
        .scaleEffect(isSelected ? 1.05 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isWeekend {
            return .secondary
        } else {
            return .primary
        }
    }
    
    private var borderColor: Color {
        if isToday && !isSelected {
            return .accentColor
        }
        return Color.white.opacity(0.2)
    }
    
    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .matchedGeometryEffect(id: "selectedDate", in: namespace)
        } else if isToday {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack {
            DateSelectorView(
                selectedDate: .constant(Date()),
                onDateChanged: { _ in }
            )
            Spacer()
        }
    }
}
