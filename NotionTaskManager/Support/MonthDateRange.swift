import Foundation

/// Represents a range of dates for a specific month
struct MonthDateRange: Equatable {
    let year: Int
    let month: Int
    let dates: [Date]
    
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .tokyo
        return cal
    }
    
    init(year: Int, month: Int) {
        self.year = year
        self.month = month
        self.dates = Self.generateDates(year: year, month: month)
    }
    
    init(containing date: Date) {
        let calendar = Self.calendar
        let components = calendar.dateComponents([.year, .month], from: date)
        self.year = components.year ?? 2025
        self.month = components.month ?? 1
        self.dates = Self.generateDates(year: self.year, month: self.month)
    }
    
    var title: String {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar
        formatter.timeZone = .tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let date = Self.calendar.date(from: components) else {
            return "\(year)年 \(month)月"
        }
        return formatter.string(from: date)
    }
    
    var previousMonth: MonthDateRange {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let date = Self.calendar.date(from: components),
              let previous = Self.calendar.date(byAdding: .month, value: -1, to: date)
        else {
            return MonthDateRange(year: month == 1 ? year - 1 : year, month: month == 1 ? 12 : month - 1)
        }
        return MonthDateRange(containing: previous)
    }
    
    var nextMonth: MonthDateRange {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let date = Self.calendar.date(from: components),
              let next = Self.calendar.date(byAdding: .month, value: 1, to: date)
        else {
            return MonthDateRange(year: month == 12 ? year + 1 : year, month: month == 12 ? 1 : month + 1)
        }
        return MonthDateRange(containing: next)
    }
    
    func contains(_ date: Date) -> Bool {
        let calendar = Self.calendar
        let components = calendar.dateComponents([.year, .month], from: date)
        return components.year == year && components.month == month
    }
    
    func index(of date: Date) -> Int? {
        let calendar = Self.calendar
        let targetDay = calendar.component(.day, from: date)
        return dates.firstIndex { calendar.component(.day, from: $0) == targetDay }
    }
    
    private static func generateDates(year: Int, month: Int) -> [Date] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth)
        else {
            return []
        }
        
        return range.compactMap { day in
            var dayComponents = components
            dayComponents.day = day
            return calendar.date(from: dayComponents)
        }
    }
}

/// Extension to check if two dates are in the same month
extension Date {
    func isInSameMonth(as other: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        let selfComponents = calendar.dateComponents([.year, .month], from: self)
        let otherComponents = calendar.dateComponents([.year, .month], from: other)
        return selfComponents.year == otherComponents.year && selfComponents.month == otherComponents.month
    }
}
