import Foundation

/// Represents a range of dates centered around a specific date
struct DateRange {
    let centerDate: Date
    let daysBeforeAndAfter: Int

    init(centerDate: Date = Date(), daysBeforeAndAfter: Int = 30) {
        self.centerDate = centerDate
        self.daysBeforeAndAfter = daysBeforeAndAfter
    }

    /// Returns an array of dates from centerDate - daysBeforeAndAfter to centerDate + daysBeforeAndAfter
    var dates: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo

        let startDate = calendar.date(
            byAdding: .day,
            value: -daysBeforeAndAfter,
            to: calendar.startOfDay(for: centerDate)
        ) ?? centerDate

        let endDate = calendar.date(
            byAdding: .day,
            value: daysBeforeAndAfter,
            to: calendar.startOfDay(for: centerDate)
        ) ?? centerDate

        var dates: [Date] = []
        var current = startDate

        while current <= endDate {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }

    /// Returns the index of the center date in the dates array
    var centerIndex: Int {
        daysBeforeAndAfter
    }
}
