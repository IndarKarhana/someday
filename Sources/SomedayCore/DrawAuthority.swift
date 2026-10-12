import CryptoKit
import Foundation

public struct SecureSnapshot: Sendable {
    public let journal: LuckyJournal
    public let date: Date
    public let phase: DrawPhase
    public let notificationsEnabled: Bool
    public let newTodayHit: LuckyHit?
    public var today: LuckyNumber? { phase == .ready ? journal.result(on: date) : nil }
}

/// The only durable authority. The encoded form belongs in device-only
/// Keychain, never the app container, export, timeline or a log. One bit per
/// authorized date keeps the two-century ledger below 10 KB before encoding.
public struct DrawAuthority: Codable, Equatable, Sendable {
    public static let maximumDays = 73_200
    public static let maximumProtectedBytes = 24_000
    public static let maximumArchiveBytes = 512_000
    private let version: Int
    public let installationID: UUID
    private let secret: Data
    public let enrolledOn: String
    public let timeZoneID: String
    private var gate: ClockGate
    private var authorizedDays: Data
    private var highestDay: Int
    private var elapsedCredit: TimeInterval
    private var creditUptime: TimeInterval
    private static let dayCost: TimeInterval = 86_400
    // One midnight-boundary allowance plus two hours for seasonal clock changes.
    // Granted only once per identity, never refilled by a restart/import.
    private static let initialCredit: TimeInterval = 93_600
    public private(set) var notificationsEnabled: Bool
    public var clock: DayClock { DayClock(timeZone: TimeZone(identifier: timeZoneID) ?? .gmt) }

    // No shipping initializer accepts a caller-supplied seed.
    public init(reading: ClockReading, timeZone: TimeZone) throws {
        try reading.validate()
        let enrollmentClock = DayClock(timeZone: timeZone)
        guard enrollmentClock.date(for: enrollmentClock.key(for: reading.wall)) != nil else { throw JournalError.invalidClock }
        version = 2
        installationID = UUID()
        secret = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        enrolledOn = DayClock(timeZone: timeZone).key(for: reading.wall)
        timeZoneID = timeZone.identifier
        gate = try ClockGate(reading)
        authorizedDays = Data([1])
        highestDay = 0
        elapsedCredit = Self.initialCredit
        creditUptime = reading.uptime
        notificationsEnabled = false
    }

    public mutating func setNotifications(_ enabled: Bool) { notificationsEnabled = enabled }

    public func journal() -> LuckyJournal {
        let first = clock.date(for: enrolledOn)!
        let draw = DailyDraw(seed: secret)
        var hits: [LuckyHit] = []
        var count = 0
        for offset in 0...highestDay where isAuthorized(offset) {
            count += 1
            let day = clock.key(for: clock.addingDays(offset, to: first))
            if let number = draw.result(on: day) {
                hits.append(LuckyHit(day: day, number: number, dayNumber: offset + 1))
            }
        }
        return LuckyJournal(installationID: installationID, enrolledOn: enrolledOn, timeZoneID: timeZoneID,
                            checkedThrough: clock.key(for: clock.addingDays(highestDay, to: first)), qualifiedDays: count, hits: hits)
    }

    /// Grants follow elapsed-time verification. A recovery file cannot supply
    /// its own clock, reset the gate or change the authoritative eligibility bits.
    public mutating func observe(_ reading: ClockReading) throws -> SecureSnapshot {
        var nextGate = gate
        let result = try nextGate.observe(reading)
        var phase = result.phase
        // Across an undetected reboot with a larger uptime, this delta can only
        // UNDERCOUNT actual elapsed time. A wall-clock change never adds credit.
        var credit = min(Double(Self.maximumDays) * Self.dayCost,
                         elapsedCredit + max(0, reading.uptime - creditUptime))
        var newToday = false
        if phase == .ready {
            guard let first = clock.date(for: enrolledOn) else { throw JournalError.invalidAuthority }
            let index = clock.calendar.dateComponents([.day], from: first, to: clock.calendar.startOfDay(for: result.date)).day ?? -1
            guard clock.date(for: clock.key(for: result.date)) != nil else { throw JournalError.invalidClock }
            guard index < Self.maximumDays else { throw JournalError.historyLimit }
            if index < highestDay {
                phase = .clockBehind
            } else {
                newToday = !isAuthorized(index)
                if result.resumed && newToday {
                    // A full verified quarantine has earned at least one credit.
                    guard credit + 0.000001 >= Self.dayCost else { throw JournalError.invalidClock }
                    authorize(index)
                    credit = max(0, credit - Self.dayCost)
                    highestDay = index
                } else if index > highestDay {
                    let affordable = Int((credit + 0.000001) / Self.dayCost)
                    let end = min(index, highestDay + affordable)
                    if end > highestDay {
                        for offset in (highestDay + 1)...end { authorize(offset) }
                        credit = max(0, credit - Double(end - highestDay) * Self.dayCost)
                        highestDay = end
                    }
                    if end < index {
                        phase = .rateLimited(until: result.date.addingTimeInterval(Self.dayCost - credit))
                    }
                }
            }
        }
        gate = nextGate
        elapsedCredit = credit
        creditUptime = reading.uptime
        let collection = journal()
        let todayHit = newToday && phase == .ready ? collection.hits.first { $0.day == clock.key(for: result.date) } : nil
        return SecureSnapshot(journal: collection, date: result.date, phase: phase,
                              notificationsEnabled: notificationsEnabled, newTodayHit: todayHit)
    }

    private func isAuthorized(_ index: Int) -> Bool {
        guard index >= 0, index / 8 < authorizedDays.count else { return false }
        return authorizedDays[index / 8] & UInt8(1 << (index % 8)) != 0
    }

    private mutating func authorize(_ index: Int) {
        precondition((0..<Self.maximumDays).contains(index))
        let bytes = index / 8 + 1
        if authorizedDays.count < bytes { authorizedDays.append(Data(repeating: 0, count: bytes - authorizedDays.count)) }
        authorizedDays[index / 8] |= UInt8(1 << (index % 8))
    }

    /// Reserved for the Keychain adapter and isolated in-memory tests.
    public func protectedRepresentation() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumProtectedBytes else { throw JournalError.invalidAuthority }
        return data
    }

    /// Trusted Keychain bytes only, never user imports. Call sites are audited.
    public static func fromProtectedRepresentation(_ data: Data) throws -> DrawAuthority {
        guard data.count <= maximumProtectedBytes else { throw JournalError.invalidAuthority }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.gate.validate()
        guard value.version == 2, value.secret.count == 32,
              value.elapsedCredit.isFinite, (0...Double(maximumDays) * Self.dayCost).contains(value.elapsedCredit),
              value.creditUptime == value.gate.lastUptime,
              TimeZone(identifier: value.timeZoneID) != nil,
              value.clock.date(for: value.enrolledOn) != nil,
              (0..<maximumDays).contains(value.highestDay),
              value.authorizedDays.count == value.highestDay / 8 + 1,
              value.isAuthorized(0), value.isAuthorized(value.highestDay) else { throw JournalError.invalidAuthority }
        let lastDate = value.clock.addingDays(value.highestDay, to: value.clock.date(for: value.enrolledOn)!)
        guard value.clock.date(for: value.clock.key(for: lastDate)) != nil else { throw JournalError.invalidAuthority }
        let usedBits = value.highestDay % 8 + 1
        if usedBits < 8, let finalByte = value.authorizedDays.last,
           finalByte >> usedBits != 0 { throw JournalError.invalidAuthority }
        return value
    }

    private var archiveKey: SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: secret), salt: Data(installationID.uuidString.utf8),
                              info: Data("someday.owner-bound.archive.v2".utf8), outputByteCount: 32)
    }
    private static let archiveContext = Data("Someday recovery file / v2 / no authority transfer".utf8)
    private struct Archive: Codable {
        let format: String
        let version: Int
        let ciphertext: Data
    }

    public func recoveryFile() throws -> Data {
        let plaintext = try JSONEncoder().encode(journal())
        let sealed = try AES.GCM.seal(plaintext, using: archiveKey, authenticating: Self.archiveContext)
        guard let ciphertext = sealed.combined else { throw JournalError.invalidArchive }
        let data = try JSONEncoder().encode(Archive(format: "someday-device-recovery", version: 2, ciphertext: ciphertext))
        guard data.count <= Self.maximumArchiveBytes else { throw JournalError.fileTooLarge }
        return data
    }

    /// Return the CURRENT Keychain-derived collection. Replay cannot roll back
    /// time, reset an owner/key, resurrect skipped dates or erase newer wins.
    public func recover(from data: Data) throws -> LuckyJournal {
        guard data.count <= Self.maximumArchiveBytes else { throw JournalError.fileTooLarge }
        do {
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            guard archive.version == 2, archive.format == "someday-device-recovery",
                  archive.ciphertext.count >= 28 else { throw JournalError.invalidArchive }
            let box = try AES.GCM.SealedBox(combined: archive.ciphertext)
            let plaintext = try AES.GCM.open(box, using: archiveKey, authenticating: Self.archiveContext)
            let imported = try JSONDecoder().decode(LuckyJournal.self, from: plaintext)
            let current = journal()
            guard imported.installationID == installationID, imported.enrolledOn == enrolledOn,
                  imported.timeZoneID == timeZoneID, imported.checkedThrough <= current.checkedThrough,
                  imported.qualifiedDays <= current.qualifiedDays,
                  imported.hits.count <= current.hits.count else { throw JournalError.invalidArchive }
            let existing = Dictionary(uniqueKeysWithValues: current.hits.map { ($0.day, $0) })
            guard Set(imported.hits.map(\.day)).count == imported.hits.count,
                  imported.hits.allSatisfy({ existing[$0.day] == $0 }) else { throw JournalError.invalidArchive }
            return current
        } catch { throw JournalError.invalidArchive }
    }
}
