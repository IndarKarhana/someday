import Foundation
import XCTest
@testable import SomedayCore

final class SomedayCoreTests: XCTestCase {
    let utc = DayClock(timeZone: .gmt)
    let seed = Data(0..<32)

    func testExactOddsForEveryTier() {
        var counts: [LuckyNumber: Int] = [:]
        var losses = 0
        for ticket in 0..<LuckyNumber.ticketCount {
            if let number = LuckyNumber.winner(forTicket: ticket) { counts[number, default: 0] += 1 }
            else { losses += 1 }
        }
        for number in LuckyNumber.allCases {
            XCTAssertEqual(counts[number], LuckyNumber.ticketCount / number.denominator)
        }
        XCTAssertEqual(losses + counts.values.reduce(0, +), LuckyNumber.ticketCount)
        XCTAssertNil(LuckyNumber.winner(forTicket: -1))
        XCTAssertNil(LuckyNumber.winner(forTicket: LuckyNumber.ticketCount))
    }

    func testDrawNeverRerollsAndHasStableGoldenVector() {
        let draw = DailyDraw(seed: seed)
        let value = draw.ticket(on: "2026-10-11")
        XCTAssertEqual(value, DailyDraw(seed: seed).ticket(on: "2026-10-11"))
        // Frozen independently verified vector guards accidental changes to v1.
        XCTAssertEqual(value, 5_440)
        for offset in 0..<1_000 {
            let day = utc.key(for: utc.addingDays(offset, to: utc.date(for: "2026-01-01")!))
            XCTAssertTrue((0..<LuckyNumber.ticketCount).contains(draw.ticket(on: day)))
        }
    }


    func testClockJumpRequiresFullPauseAndSkipsGap() throws {
        let start = utc.date(for: "2026-01-01")!
        var owner = try DrawAuthority(reading: ClockReading(wall: start, uptime: 100), timeZone: .gmt)
        let jump = start.addingTimeInterval(1000 * 86400)
        let held = try owner.observe(ClockReading(wall: jump, uptime: 101))
        XCTAssertNotEqual(held.phase, .ready)
        XCTAssertEqual(held.journal.qualifiedDays, 1)
        let resumed = try owner.observe(ClockReading(wall: jump.addingTimeInterval(86400), uptime: 86501))
        XCTAssertEqual(resumed.phase, .ready)
        XCTAssertEqual(resumed.journal.qualifiedDays, 2)
    }

    func testRecoveryCannotTransferOrRollBackIdentity() throws {
        let start = utc.date(for: "2026-01-01")!
        var owner = try DrawAuthority(reading: ClockReading(wall: start, uptime: 100), timeZone: .gmt)
        let old = try owner.recoveryFile()
        _ = try owner.observe(ClockReading(wall: start.addingTimeInterval(86400), uptime: 86500))
        XCTAssertEqual(try owner.recover(from: old), owner.journal())
        let other = try DrawAuthority(reading: ClockReading(wall: start, uptime: 100), timeZone: .gmt)
        XCTAssertThrowsError(try other.recover(from: old))
        XCTAssertThrowsError(try owner.recover(from: owner.protectedRepresentation()))
    }

    func testDSTAndInvalidDates() {
        let chicago = DayClock(timeZone: TimeZone(identifier: "America/Chicago")!)
        let spring = chicago.date(for: "2026-03-08")!
        XCTAssertEqual(chicago.nextMidnight(after: spring).timeIntervalSince(spring), 23 * 3600)
        let fall = chicago.date(for: "2026-11-01")!
        XCTAssertEqual(chicago.nextMidnight(after: fall).timeIntervalSince(fall), 25 * 3600)
        XCTAssertNil(utc.date(for: "2026-02-30"))
        XCTAssertNil(utc.date(for: "2026-1-1"))
    }
}
