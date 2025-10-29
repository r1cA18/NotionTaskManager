import Foundation

struct DateBoundaries {
    let startOfDay: Date
    let startOfTomorrow: Date

    init(target: Date, timeZone: TimeZone = .tokyo) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        startOfDay = calendar.startOfDay(for: target)
        startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? startOfDay.addingTimeInterval(86_400)
    }

    func contains(_ date: Date) -> Bool {
        date >= startOfDay && date < startOfTomorrow
    }
}

extension TimeZone {
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
}

extension Date {
    /// Returns the start of today in JST (Asia/Tokyo timezone)
    static func todayInJST() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.startOfDay(for: Date())
    }

    /// Returns the start of this date in JST (Asia/Tokyo timezone)
    func startOfDayInJST() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.startOfDay(for: self)
    }
}
