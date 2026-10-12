import Foundation

/// Shipping input comes from Date + mach_continuous_time, never a backup/URL.
public struct ClockReading: Sendable {
    public let wall: Date
    public let uptime: TimeInterval

    public init(wall: Date, uptime: TimeInterval) {
        self.wall = wall
        self.uptime = uptime
    }

    func validate() throws {
        let seconds = wall.timeIntervalSince1970
        guard seconds.isFinite, (-62_135_596_800...253_402_214_400).contains(seconds),
              uptime.isFinite, uptime >= 0, uptime < 1e12 else { throw JournalError.invalidClock }
    }
}

public enum DrawPhase: Equatable, Sendable {
    case ready
    case verifying(until: Date)
    case rateLimited(until: Date)
    case clockBehind
    case unavailable

    public var message: String? {
        switch self {
        case .ready: return nil
        case .verifying:
            return "A restart or clock change interrupted verification. Draws resume after 24 continuous hours with a stable clock. Days in the unverified gap are not awarded. Your saved wins are safe."
        case .rateLimited:
            return "Today’s draw is waiting for enough verified elapsed time. This prevents repeated clock changes from creating extra chances. Your saved wins are safe."
        case .unavailable:
            return "Protected storage could not be checked. Unlock your device and try again. Draws are paused; Someday will never reset your identity automatically."
        case .clockBehind:
            return "Your clock is behind a previously checked day. Set Date & Time automatically in iOS Settings. Your saved wins are safe."
        }
    }
}

struct ClockGate: Codable, Equatable, Sendable {
    static let verificationInterval: TimeInterval = 86_400
    static let driftTolerance: TimeInterval = 180
    private(set) var anchorWall: Date
    private(set) var anchorUptime: TimeInterval
    private(set) var lastUptime: TimeInterval
    private(set) var needsVerification: Bool

    init(_ reading: ClockReading) throws {
        try reading.validate()
        anchorWall = reading.wall
        anchorUptime = reading.uptime
        lastUptime = reading.uptime
        needsVerification = false
    }

    func validate() throws {
        try ClockReading(wall: anchorWall, uptime: anchorUptime).validate()
        guard lastUptime.isFinite, lastUptime >= anchorUptime, lastUptime < 1e12 else { throw JournalError.invalidAuthority }
    }

    /// Keep a fixed anchor. Rebasing on every observation would allow an
    /// attacker to accumulate many individually tolerated small clock changes.
    mutating func observe(_ reading: ClockReading) throws -> (date: Date, phase: DrawPhase, resumed: Bool) {
        try reading.validate()
        let elapsed = reading.uptime - anchorUptime
        let expected = anchorWall.addingTimeInterval(elapsed)
        if reading.uptime < lastUptime || abs(reading.wall.timeIntervalSince(expected)) > Self.driftTolerance {
            anchorWall = reading.wall
            anchorUptime = reading.uptime
            lastUptime = reading.uptime
            needsVerification = true
            return (reading.wall, .verifying(until: reading.wall.addingTimeInterval(Self.verificationInterval)), false)
        }
        lastUptime = reading.uptime
        if needsVerification {
            guard elapsed >= Self.verificationInterval else {
                return (expected, .verifying(until: anchorWall.addingTimeInterval(Self.verificationInterval)), false)
            }
            needsVerification = false
            return (expected, .ready, true)
        }
        return (expected, .ready, false)
    }
}
