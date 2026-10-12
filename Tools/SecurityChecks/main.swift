// Adversarial harness: isolated identities, simulated clock input, no real Keychain.
import CryptoKit
import Darwin
import Foundation
import SomedayCore

struct Failure: Error, CustomStringConvertible { let description: String }
func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw Failure(description: message) }
}
func rejects(_ body: () throws -> Void) -> Bool {
    do { try body(); return false } catch { return true }
}
let start = DayClock(timeZone: .gmt).date(for: "2026-01-01")!
func reading(_ seconds: Double, uptime: Double? = nil) -> ClockReading {
    ClockReading(wall: start.addingTimeInterval(seconds), uptime: uptime ?? (100000 + seconds))
}
func fresh() throws -> DrawAuthority { try DrawAuthority(reading: reading(0), timeZone: .gmt) }
var checks = 0
func check(_ name: String, _ body: () throws -> Void) throws {
    try body(); checks += 1; print("PASS  \(name)")
}

do {
    try check("A century of wall-clock acceleration grants no extra dates") {
        var owner = try fresh()
        let original = owner.journal()
        let result = try owner.observe(reading(36500 * 86400, uptime: 100001))
        try expect(result.phase != .ready, "Clock jump bypassed verification")
        try expect(result.journal == original, "Clock jump manufactured wins")
        for offset in 1...100 {
            _ = try owner.observe(reading(Double(36500 + offset) * 86400, uptime: 100001 + Double(offset)))
        }
        try expect(owner.journal() == original, "Repeated forward jumps manufactured wins")
    }
    try check("24-hour quarantine uses elapsed time, then grants only one date") {
        var owner = try fresh()
        let future = 1000.0 * 86400
        _ = try owner.observe(reading(future, uptime: 100001))
        let early = try owner.observe(reading(future + 86399, uptime: 186400))
        try expect(early.phase != .ready && early.journal.qualifiedDays == 1, "Early unlock")
        let resumed = try owner.observe(reading(future + 86400, uptime: 186401))
        try expect(resumed.phase == .ready && resumed.journal.qualifiedDays == 2, "Gap backfilled or failed to resume")
        let later = try owner.observe(reading(future + 2 * 86400, uptime: 272801))
        try expect(later.journal.qualifiedDays == 3, "Skipped dates resurrected")
    }
    try check("Reboot and repeated reboot restart the full verification timer") {
        var owner = try fresh()
        _ = try owner.observe(reading(10, uptime: 1))
        let waiting = try owner.observe(reading(86409, uptime: 86400))
        try expect(waiting.phase != .ready, "Short reboot verification")
        _ = try owner.observe(reading(86410, uptime: 1))
        let waitingAgain = try owner.observe(reading(172809, uptime: 86400))
        try expect(waitingAgain.phase != .ready, "Second reboot retained old elapsed time")
        let done = try owner.observe(reading(172810, uptime: 86401))
        try expect(done.phase == .ready && done.journal.qualifiedDays == 2, "Reboot gap backfill")
    }
    try check("Small per-observation clock changes cannot accumulate grants") {
        var owner = try fresh()
        for offset in 1...2000 {
            _ = try owner.observe(reading(Double(offset) * 120, uptime: 100000 + Double(offset)))
        }
        try expect(owner.journal().qualifiedDays == 1, "Gradual drift bypassed fixed anchor")
    }
    try check("Backward clock cannot roll history back") {
        var owner = try fresh()
        _ = try owner.observe(reading(10 * 86400))
        let original = owner.journal()
        _ = try owner.observe(reading(-3 * 86400, uptime: 100000 + 10 * 86400 + 1))
        let snapshot = try owner.observe(reading(-2 * 86400, uptime: 100000 + 11 * 86400 + 1))
        try expect(snapshot.phase == .clockBehind, "Backwards clock unlocked")
        try expect(owner.journal() == original, "History rolled back")
    }
    try check("Invalid readings fail transactionally") {
        var owner = try fresh()
        let original = owner
        try expect(rejects { _ = try DrawAuthority(reading: ClockReading(wall: Date(timeIntervalSince1970: .nan), uptime: 1), timeZone: .gmt) }, "Invalid enrollment accepted")
        for invalid in [ClockReading(wall: Date(timeIntervalSince1970: .nan), uptime: 1),
                        ClockReading(wall: start, uptime: -.infinity),
                        ClockReading(wall: start, uptime: -1),
                        ClockReading(wall: start, uptime: .nan)] {
            try expect(rejects { _ = try owner.observe(invalid) }, "Invalid clock accepted")
            try expect(owner == original, "Failed observation changed state")
        }
        try expect(rejects { _ = try owner.observe(reading(73200 * 86400)) }, "Unbounded history accepted")
        try expect(owner == original, "History-limit failure changed state")
    }
    try check("Old signed backup replay preserves new wins and clock quarantine") {
        var owner = try fresh()
        let old = try owner.recoveryFile()
        _ = try owner.observe(reading(3650 * 86400))
        _ = try owner.observe(reading(9000 * 86400, uptime: 100000 + 3650 * 86400 + 1))
        let original = owner
        let recovered = try owner.recover(from: old)
        try expect(recovered == owner.journal() && owner == original, "Replay changed authority or lost newer records")
    }
    try check("Other identities and raw protected state cannot be imported") {
        let owner = try fresh()
        let attacker = try fresh()
        let foreign = try attacker.recoveryFile()
        try expect(rejects { _ = try owner.recover(from: foreign) }, "Foreign identity adopted")
        let raw = try attacker.protectedRepresentation()
        try expect(rejects { _ = try owner.recover(from: raw) }, "Raw authority accepted as import")
        let export = try owner.recoveryFile()
        let internalJSON = try JSONSerialization.jsonObject(with: owner.protectedRepresentation()) as! [String: Any]
        let secret = internalJSON["secret"] as! String
        try expect(!String(decoding: export, as: UTF8.self).contains(secret), "Secret leaked into export")
    }
    try check("Old seed-grinding exploit produces a number 1, but cannot import it") {
        // Independent attacker chooses a seed giving today's jackpot.
        let day = "2026-01-01"
        var candidate = Data()
        var attempts = 0
        repeat {
            candidate = Data(SHA256.hash(data: Data("attacker-\(attempts)".utf8)))
            attempts += 1
        } while DailyDraw(seed: candidate).result(on: day) != .one && attempts < 1_000_000
        try expect(DailyDraw(seed: candidate).result(on: day) == .one, "Attack fixture not generated")
        let fake: [String: Any] = ["version": 1, "seed": candidate.base64EncodedString(),
            "installationID": UUID().uuidString, "enrolledOn": day, "timeZoneID": "GMT",
            "checkedThrough": day, "hits": [["day": day, "number": 1, "dayNumber": 1]]]
        let bytes = try JSONSerialization.data(withJSONObject: fake)
        let owner = try fresh()
        try expect(rejects { _ = try owner.recover(from: bytes) }, "Seed-grinded jackpot imported")
        print("      Forged jackpot after \(attempts) candidate seeds: rejected by production import")
    }
    try check("Every encrypted payload byte rejects bit-flip tampering") {
        let owner = try fresh()
        var envelope = try JSONSerialization.jsonObject(with: owner.recoveryFile()) as! [String: Any]
        let ciphertext = Data(base64Encoded: envelope["ciphertext"] as! String)!
        for index in ciphertext.indices {
            var altered = ciphertext
            altered[index] ^= 1
            envelope["ciphertext"] = altered.base64EncodedString()
            let bytes = try JSONSerialization.data(withJSONObject: envelope)
            try expect(rejects { _ = try owner.recover(from: bytes) }, "Ciphertext edit accepted at \(index)")
        }
        for length in [0, 1, 12, 27, ciphertext.count - 1] {
            envelope["ciphertext"] = ciphertext.prefix(length).base64EncodedString()
            let bytes = try JSONSerialization.data(withJSONObject: envelope)
            try expect(rejects { _ = try owner.recover(from: bytes) }, "Truncated encryption accepted")
        }
    }
    try check("2,000 deterministic malformed imports fail without mutation") {
        let owner = try fresh()
        let before = owner
        var random: UInt64 = 0x123456789abcdef
        for iteration in 0..<2000 {
            let data = Data((0..<(iteration % 1024)).map { _ -> UInt8 in
                random = random &* 6364136223846793005 &+ 1
                return UInt8(truncatingIfNeeded: random >> 32)
            })
            try expect(rejects { _ = try owner.recover(from: data) }, "Malformed import accepted")
        }
        try expect(owner == before, "Fuzzing changed owner")
        try expect(rejects { _ = try owner.recover(from: Data(repeating: 0, count: 512001)) }, "Oversize accepted")
    }
    try check("Bounded imports reject oversized files, directories, symlinks and FIFOs") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SomedaySecurity-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("input.json")
        try Data(repeating: 7, count: 1025).write(to: file)
        try expect(rejects { _ = try BoundedFile.read(file, limit: 1024) }, "Oversize file accepted")
        let exact = try BoundedFile.read(file, limit: 1025)
        try expect(exact.count == 1025, "Exact size rejected")
        let link = directory.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        try expect(rejects { _ = try BoundedFile.read(link) }, "Symlink accepted")
        try expect(rejects { _ = try BoundedFile.read(directory) }, "Directory accepted")
        let fifo = directory.appendingPathComponent("pipe.json")
        try expect(mkfifo(fifo.path, 0o600) == 0, "FIFO fixture failed")
        try expect(rejects { _ = try BoundedFile.read(fifo) }, "FIFO accepted")
    }
    try check("Repeated quarantine at midnight cannot double the long-term draw rate") {
        var owner = try fresh()
        var realSeconds = 0.0
        for cycle in 1...10 {
            let jump = Double(cycle * 1000) * 86400 + 86399
            realSeconds += 1
            _ = try owner.observe(reading(jump, uptime: 100000 + realSeconds))
            realSeconds += 86400
            _ = try owner.observe(reading(jump + 86400, uptime: 100000 + realSeconds))
            realSeconds += 1
            _ = try owner.observe(reading(jump + 86401, uptime: 100000 + realSeconds))
        }
        try expect(owner.journal().qualifiedDays <= Int((realSeconds + 93600) / 86400) + 1,
                   "Boundary attack amplified draws: \(owner.journal().qualifiedDays) dates in \(realSeconds / 86400) elapsed days")
    }
    try check("Randomized restarts and wall-clock attacks preserve the lifetime rate bound") {
        var owner = try fresh()
        var rng: UInt64 = 20261011
        func random(_ limit: UInt64) -> UInt64 {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return (rng >> 24) % limit
        }
        var realSeconds = 0.0
        var uptime = 100000.0
        var wallSeconds = 0.0
        for _ in 0..<5000 {
            let delta = Double(random(90000))
            realSeconds += delta
            uptime += delta
            wallSeconds += delta
            if random(11) == 0 { uptime = Double(random(1000)) }
            if random(7) == 0 { wallSeconds = Double(random(4000 * 86400)) }
            let snapshot = try owner.observe(reading(wallSeconds, uptime: uptime))
            let bound = 1 + Int((realSeconds + 93600) / 86400)
            try expect(snapshot.journal.qualifiedDays <= bound, "Random trace amplified eligibility")
            try expect(Set(snapshot.journal.hits.map(\.day)).count == snapshot.journal.hits.count, "Duplicate win")
        }
    }
    try check("Spring DST and late enrollment do not consume extra daily chances") {
        let clock = DayClock(timeZone: TimeZone(identifier: "America/Chicago")!)
        let beginning = clock.date(for: "2026-03-08")!.addingTimeInterval(-1)
        var owner = try DrawAuthority(reading: ClockReading(wall: beginning, uptime: 1), timeZone: clock.timeZone)
        let midnight = clock.date(for: "2026-03-08")!
        let first = try owner.observe(ClockReading(wall: midnight, uptime: 2))
        let next = clock.date(for: "2026-03-09")!
        let second = try owner.observe(ClockReading(wall: next, uptime: 1 + next.timeIntervalSince(beginning)))
        try expect(first.phase == .ready && second.phase == .ready, "Ordinary DST triggered rate restriction")
        try expect(second.journal.qualifiedDays == 3, "Lost a legitimate calendar date")
    }
    try check("Nested JSON, modified headers, and the maximum ledger are bounded") {
        let owner = try fresh()
        let nested = Data((String(repeating: "[", count: 10000) + "0" + String(repeating: "]", count: 10000)).utf8)
        try expect(rejects { _ = try owner.recover(from: nested) }, "Nested JSON accepted")
        var envelope = try JSONSerialization.jsonObject(with: owner.recoveryFile()) as! [String: Any]
        for (field, bad) in [("format", "other" as Any), ("version", 999 as Any), ("ciphertext", "not-base64" as Any)] {
            let original = envelope[field]
            envelope[field] = bad
            let data = try JSONSerialization.data(withJSONObject: envelope)
            try expect(rejects { _ = try owner.recover(from: data) }, "Invalid envelope field accepted")
            envelope[field] = original
        }
        var maximum = owner
        _ = try maximum.observe(reading(Double(DrawAuthority.maximumDays - 1) * 86400))
        let protected = try maximum.protectedRepresentation()
        let restored = try DrawAuthority.fromProtectedRepresentation(protected)
        try expect(restored == maximum && protected.count < 14000, "Maximum ledger cannot persist compactly")
    }
    try check("Corrupt protected bytes never silently create a replacement identity") {
        let owner = try fresh()
        let json = try JSONSerialization.jsonObject(with: owner.protectedRepresentation()) as! [String: Any]
        for (key, bad) in [("version", 1 as Any), ("secret", "AQ==" as Any), ("highestDay", -1 as Any),
                           ("elapsedCredit", -1 as Any), ("creditUptime", 1 as Any), ("authorizedDays", "AA==" as Any), ("timeZoneID", "Invalid" as Any)] {
            var mutation = json; mutation[key] = bad
            let data = try JSONSerialization.data(withJSONObject: mutation)
            try expect(rejects { _ = try DrawAuthority.fromProtectedRepresentation(data) }, "Invalid protected field accepted: \(key)")
        }
    }
    print("\n\(checks) adversarial suites passed. No device or sandbox-compromise guarantee.")
} catch {
    fputs("FAIL  \(error)\n", stderr)
    exit(1)
}
