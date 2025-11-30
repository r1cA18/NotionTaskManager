import SwiftUI
import Combine

/// Horizontal scrollable date selector limited to a single month with navigation
struct DateSelectorView: View {
    @Binding var selectedDate: Date
    let onDateChanged: (Date) -> Void
    
    @State private var monthRange: MonthDateRange
    @State private var scrollPosition: Date?
    @State private var isUserScrolling = false
    @State private var debounceTask: Task<Void, Never>?
    
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
        VStack(spacing: 8) {
            // Month navigation header
            monthHeader
            
            // Date cells scroll view
            dateScrollView
        }
    }
    
    private var monthHeader: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    monthRange = monthRange.previousMonth
                    // Select first day of new month
                    if let firstDay = monthRange.dates.first {
                        selectedDate = firstDay
                        scrollPosition = firstDay
                        onDateChanged(firstDay)
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(monthRange.title)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    monthRange = monthRange.nextMonth
                    // Select first day of new month
                    if let firstDay = monthRange.dates.first {
                        selectedDate = firstDay
                        scrollPosition = firstDay
                        onDateChanged(firstDay)
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
    
    private var dateScrollView: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Left padding for center alignment
                    Spacer()
                        .frame(width: (geometry.size.width - 52) / 2)
                    
                    ForEach(monthRange.dates, id: \.self) { date in
                        DateCell(
                            date: date,
                            isSelected: isSameDay(date, selectedDate)
                        )
                        .onTapGesture {
                            selectDate(date, animated: true)
                        }
                    }
                    
                    // Right padding for center alignment
                    Spacer()
                        .frame(width: (geometry.size.width - 52) / 2)
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: scrollPosition) { oldValue, newValue in
                handleScrollPositionChange(from: oldValue, to: newValue)
            }
        }
        .frame(height: 64)
        .onChange(of: selectedDate) { oldValue, newValue in
            handleSelectedDateChange(from: oldValue, to: newValue)
        }
        .onAppear {
            setupInitialPosition()
        }
    }
    
    private func handleScrollPositionChange(from oldValue: Date?, to newValue: Date?) {
        guard let newValue else { return }
        
        // Cancel any pending debounce
        debounceTask?.cancel()
        
        // Debounce the selection update
        debounceTask = Task { @MainActor in
            // Wait for scroll to settle
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            
            guard !Task.isCancelled else { return }
            
            // Find the closest date in the current month
            let closestDate = findClosestDate(to: newValue)
            
            if !isSameDay(closestDate, selectedDate) {
                selectedDate = closestDate
                onDateChanged(closestDate)
            }
        }
    }
    
    private func handleSelectedDateChange(from oldValue: Date, to newValue: Date) {
        guard !isSameDay(oldValue, newValue) else { return }
        
        // Check if we need to change months
        if !monthRange.contains(newValue) {
            withAnimation(.easeInOut(duration: 0.3)) {
                monthRange = MonthDateRange(containing: newValue)
            }
        }
        
        // Update scroll position without animation if already in view
        if monthRange.contains(newValue) {
            scrollPosition = newValue.startOfDayInJST()
        }
    }
    
    private func selectDate(_ date: Date, animated: Bool) {
        debounceTask?.cancel()
        
        let normalizedDate = date.startOfDayInJST()
        
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = normalizedDate
                scrollPosition = normalizedDate
            }
        } else {
            selectedDate = normalizedDate
            scrollPosition = normalizedDate
        }
        
        onDateChanged(normalizedDate)
    }
    
    private func setupInitialPosition() {
        let today = Date.todayInJST()
        
        // Update month range if needed
        if !monthRange.contains(today) {
            monthRange = MonthDateRange(containing: today)
        }
        
        // Set initial scroll position without animation
        scrollPosition = today
    }
    
    private func findClosestDate(to targetDate: Date) -> Date {
        let targetStart = targetDate.startOfDayInJST()
        
        var closestDate = monthRange.dates.first ?? targetStart
        var minDifference = TimeInterval.greatestFiniteMagnitude
        
        for date in monthRange.dates {
            let dateStart = date.startOfDayInJST()
            let difference = abs(targetStart.timeIntervalSince(dateStart))
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

/// Individual date cell in the horizontal selector (circular design)
struct DateCell: View {
    let date: Date
    let isSelected: Bool
    
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
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(weekdayString)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textColor)
            
            Text(dayNumber)
                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                .foregroundStyle(textColor)
        }
        .frame(width: 52, height: 52)
        .background(background)
        .clipShape(Circle())
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1),
            radius: isSelected ? 6 : 3,
            x: 0,
            y: isSelected ? 3 : 2
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
    
    @ViewBuilder
    private var background: some View {
        if isSelected {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                .shadow(color: Color.white.opacity(0.8), radius: 3, x: -2, y: -2)
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 2, y: 2)
        }
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
