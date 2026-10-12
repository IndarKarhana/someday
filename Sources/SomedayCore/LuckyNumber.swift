import Foundation

public enum LuckyNumber: Int, Codable, CaseIterable, Identifiable, Sendable {
    case one = 1, two, three, four, five

    public var id: Int { rawValue }

    public var denominator: Int {
        switch self {
        case .one: return 36_500
        case .two: return 7_300
        case .three: return 1_825
        case .four: return 365
        case .five: return 60
        }
    }

    public var name: String {
        switch self {
        case .one: return "Once in a someday"
        case .two: return "A beautiful rarity"
        case .three: return "Quite extraordinary"
        case .four: return "Something special"
        case .five: return "A little lovely luck"
        }
    }

    public var averageInterval: String {
        switch self {
        case .one: return "100 years"
        case .two: return "20 years"
        case .three: return "5 years"
        case .four: return "1 year"
        case .five: return "60 days"
        }
    }

    public var oddsLabel: String { "1 in \(denominator.formatted(.number.locale(Locale(identifier: "en_US"))))" }

    // A common denominator makes every tier's stated daily probability exact.
    // The intervals are disjoint, so a day has at most one winning number.
    public static let ticketCount = 219_000

    public static func winner(forTicket ticket: Int) -> LuckyNumber? {
        guard (0..<ticketCount).contains(ticket) else { return nil }
        var upperBound = 0
        for number in allCases {
            upperBound += ticketCount / number.denominator
            if ticket < upperBound { return number }
        }
        return nil
    }
}
