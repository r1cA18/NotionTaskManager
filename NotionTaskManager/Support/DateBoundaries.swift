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
