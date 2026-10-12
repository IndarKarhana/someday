import Foundation

/// The enrollment timezone stays fixed. Travel and daylight-saving transitions
/// do not provide extra draws or change an existing date's result.
public struct DayClock: Sendable {
    public let timeZone: TimeZone

    public init(timeZone: TimeZone) { self.timeZone = timeZone }

    public var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        value.locale = Locale(identifier: "en_US_POSIX")
        return value
    }

    public func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    public func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard key.count == 10, parts.count == 3, (1...9999).contains(parts[0]),
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              self.key(for: date) == key else { return nil }
        return date
    }

    public func addingDays(_ count: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: count, to: date)!
    }

    public func nextMidnight(after date: Date) -> Date {
        addingDays(1, to: calendar.startOfDay(for: date))
    }

    public func dayNumber(on date: Date, enrolledOn: String) -> Int {
        guard let first = self.date(for: enrolledOn) else { return 0 }
        return max(0, (calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: date)).day ?? -1) + 1)
    }

    public func label(for key: String, style: DateFormatter.Style = .long) -> String {
        guard let date = date(for: key) else { return key }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateStyle = style
        return formatter.string(from: date)
    }
}
