import Foundation
import SomedayCore

struct CheckFailure: Error, CustomStringConvertible { let description: String }

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(description: message) }
}

func rejects(_ body: () throws -> Void) -> Bool {
    do { try body(); return false } catch { return true }
}

let seed = Data(0..<32)
let utc = DayClock(timeZone: .gmt)
var checks = 0

func check(_ name: String, _ body: () throws -> Void) throws {
    try body()
    checks += 1
    print("PASS  \(name)")
}

do {
    try check("Exact tier probabilities across all 219,000 possible tickets") {
        var counts: [LuckyNumber: Int] = [:]
        var misses = 0
        for ticket in 0..<LuckyNumber.ticketCount {
            if let number = LuckyNumber.winner(forTicket: ticket) { counts[number, default: 0] += 1 }
            else { misses += 1 }
        }
        for number in LuckyNumber.allCases {
            try expect(counts[number] == LuckyNumber.ticketCount / number.denominator, "Incorrect odds for \(number)")
        }
        try expect(misses == 214_594, "Incorrect non-winning probability")
        try expect(LuckyNumber.winner(forTicket: -1) == nil, "Negative ticket accepted")
        try expect(LuckyNumber.winner(forTicket: LuckyNumber.ticketCount) == nil, "Out-of-range ticket accepted")
    }

    try check("Stable HMAC test vector, independently checked with Python hashlib") {
        try expect(DailyDraw(seed: seed).ticket(on: "2026-10-11") == 5_440, "v1 result changed")
        let day = "2026-10-11"
        for _ in 0..<100 {
            try expect(DailyDraw(seed: seed).ticket(on: day) == 5_440, "Reopening rerolled the day")
        }
    }

    try check("All draws remain in range across 100 years") {
        let first = utc.date(for: "2026-01-01")!
        let draw = DailyDraw(seed: seed)
        for offset in 0..<36_500 {
            let day = utc.key(for: utc.addingDays(offset, to: first))
            try expect((0..<LuckyNumber.ticketCount).contains(draw.ticket(on: day)), "Out-of-range draw on \(day)")
        }
    }

    try check("Different installation keys produce different daily sequences") {
        let other = DailyDraw(seed: Data(repeating: 42, count: 32))
        let original = DailyDraw(seed: seed)
        try expect((1...30).contains { other.ticket(on: "2026-10-\($0)") != original.ticket(on: "2026-10-\($0)") }, "Seeds made identical sequences")
    }

    try check("Leap days, DST, midnight boundaries and invalid calendar dates") {
        let clock = DayClock(timeZone: TimeZone(identifier: "America/Chicago")!)
        let spring = clock.date(for: "2026-03-08")!
        let fall = clock.date(for: "2026-11-01")!
        try expect(clock.nextMidnight(after: spring).timeIntervalSince(spring) == 23 * 3_600, "Spring DST failed")
        try expect(clock.nextMidnight(after: fall).timeIntervalSince(fall) == 25 * 3_600, "Fall DST failed")
        try expect(utc.key(for: utc.addingDays(1, to: utc.date(for: "2028-02-28")!)) == "2028-02-29", "Leap day lost")
        try expect(clock.key(for: clock.nextMidnight(after: spring).addingTimeInterval(-1)) == "2026-03-08", "Early midnight change")
        for invalid in ["2026-02-30", "2026-1-1", "hello", "999999-01-01", "0000-01-01"] {
            try expect(utc.date(for: invalid) == nil, "Accepted \(invalid)")
        }
    }


    try check("Verified catchup exactly matches daily visits; repeat opens never reroll") {
        let first = utc.date(for: "2026-01-01")!
        var daily = try DrawAuthority(reading: ClockReading(wall: first, uptime: 10), timeZone: .gmt)
        var missed = daily
        for offset in 0...180 {
            _ = try daily.observe(ClockReading(wall: first.addingTimeInterval(Double(offset) * 86400), uptime: 10 + Double(offset) * 86400))
        }
        _ = try missed.observe(ClockReading(wall: first.addingTimeInterval(180 * 86400), uptime: 10 + 180 * 86400))
        try expect(daily == missed, "Catchup differs from daily observations")
        let before = missed
        _ = try missed.observe(ClockReading(wall: first.addingTimeInterval(180 * 86400), uptime: 10 + 180 * 86400))
        try expect(missed == before, "Repeated observation changed authority")
        try expect(missed.journal().qualifiedDays == 181, "Wrong eligible count")
        try expect(missed.journal().result(on: first.addingTimeInterval(181 * 86400)) == nil, "Future draw leaked")
    }

    try check("Protected storage and authenticated recovery roundtrip") {
        let value = try DrawAuthority(reading: ClockReading(wall: Date(), uptime: 10), timeZone: .gmt)
        let decoded = try DrawAuthority.fromProtectedRepresentation(value.protectedRepresentation())
        try expect(value == decoded, "Protected roundtrip changed authority")
        let recovered = try value.recover(from: value.recoveryFile())
        try expect(recovered == value.journal(), "Recovery changed collection")
    }

    try check("100-year history size and recomputation cost") {
        let first = utc.date(for: "2026-01-01")!
        var value = try DrawAuthority(reading: ClockReading(wall: first, uptime: 0), timeZone: .gmt)
        let started = Date()
        _ = try value.observe(ClockReading(wall: first.addingTimeInterval(36500 * 86400), uptime: 36500 * 86400))
        let elapsed = Date().timeIntervalSince(started)
        let bytes = try value.protectedRepresentation().count
        try expect(bytes < 7000, "Protected state unexpectedly large")
        print("      100 simulated years: \(bytes) protected bytes; \(String(format: "%.3f", elapsed))s recomputation on this Mac")
    }
    print("\n\(checks) core checks passed.")
} catch {
    fputs("FAIL  \(error)\n", stderr)
    exit(1)
}
