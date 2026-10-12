import Foundation

public struct LuckyHit: Codable, Identifiable, Equatable, Sendable {
    public let day: String
    public let number: LuckyNumber
    public let dayNumber: Int
    public var id: String { day }

    public init(day: String, number: LuckyNumber, dayNumber: Int) {
        self.day = day
        self.number = number
        self.dayNumber = dayNumber
    }
}

/// Read-only presentation of authorized days. No secret or future-draw access.
public struct LuckyJournal: Codable, Equatable, Sendable {
    public let installationID: UUID
    public let enrolledOn: String
    public let timeZoneID: String
    public let checkedThrough: String
    public let qualifiedDays: Int
    public let hits: [LuckyHit]

    public var clock: DayClock { DayClock(timeZone: TimeZone(identifier: timeZoneID) ?? .gmt) }

    public func result(on date: Date) -> LuckyNumber? {
        let day = clock.key(for: date)
        return hits.first { $0.day == day }?.number
    }
}

public enum JournalError: LocalizedError {
    case invalidArchive, invalidAuthority, sharedContainerUnavailable, identityMissing
    case legacyState, invalidClock, historyLimit, storageBusy, fileTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "This backup could not be authenticated for this installation. Unsigned files, edited backups, and backups from another device cannot add wins. Your collection has not changed."
        case .invalidAuthority:
            return "Someday couldn’t validate its protected identity. Draws are paused; a new identity will not be created automatically."
        case .sharedContainerUnavailable:
            return "Someday’s shared storage is unavailable. Check App Group and Keychain Sharing configuration for both targets in Xcode."
        case .identityMissing:
            return "The original device-bound identity is unavailable. Backups cannot replace it or create a new draw identity."
        case .legacyState:
            return "This is an unsigned development-era collection. It cannot be upgraded into authenticated wins. The original file has been left untouched."
        case .invalidClock:
            return "Someday can’t establish a valid elapsed-time reading. Draws are paused."
        case .historyLimit:
            return "The device date falls outside this collection’s supported lifetime. Check Date & Time in iOS Settings."
        case .storageBusy:
            return "Someday is updating its protected collection. Please try again in a moment."
        case .fileTooLarge:
            return "This file is too large to be a Someday recovery file."
        }
    }
}
