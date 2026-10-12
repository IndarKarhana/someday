import Darwin
import Foundation
import UserNotifications

enum SharedStorage {
    static let widgetKind = "SomedayDailyWidget"

    private static func directory() throws -> URL {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SomedayAppGroup") as? String,
              !group.isEmpty, !group.contains("$("),
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw JournalError.sharedContainerUnavailable }
        return root.appendingPathComponent("Journal", isDirectory: true)
    }

    /// Serialize read/check/commit across app AND widget processes. The Keychain
    /// commit happens before a result is released to either UI or notifications.
    private static func locked<T>(_ operation: (URL) throws -> T) throws -> T {
        let directory = try directory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = directory.appendingPathComponent("authority.lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw JournalError.storageBusy }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw JournalError.storageBusy }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try operation(directory)
    }

    private static func markIdentity(in directory: URL) throws {
        let marker = directory.appendingPathComponent("identity-v2.present")
        if !FileManager.default.fileExists(atPath: marker.path) {
            try Data("Someday device identity exists; never reset automatically.".utf8)
                .write(to: marker, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    static func load(enrollIfMissing: Bool = false) throws -> SecureSnapshot? {
        let snapshot = try locked { directory -> SecureSnapshot? in
            let reading = try DeviceClock.read()
            if var authority = try KeychainAuthority.read() {
                let result = try authority.observe(reading)
                try KeychainAuthority.update(authority)
                try markIdentity(in: directory)
                return result
            }
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("identity-v2.present").path) {
                throw JournalError.identityMissing
            }
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("someday-v1.json").path) {
                throw JournalError.legacyState
            }
            guard enrollIfMissing else { return nil }
            var authority = try DrawAuthority(reading: reading, timeZone: .current)
            let result = try authority.observe(reading)
            try KeychainAuthority.create(authority)
            try markIdentity(in: directory)
            return result
        }
        notifyIfNeeded(snapshot)
        return snapshot
    }

    static func exportRecovery() throws -> Data {
        try locked { _ in
            guard let authority = try KeychainAuthority.read() else { throw JournalError.identityMissing }
            return try authority.recoveryFile()
        }
    }

    static func validateRecovery(_ data: Data) throws {
        try locked { _ in
            guard let authority = try KeychainAuthority.read() else { throw JournalError.identityMissing }
            _ = try authority.recover(from: data)
        }
    }

    static func restoreRecovery(_ data: Data) throws -> SecureSnapshot {
        let snapshot = try locked { directory in
            guard var authority = try KeychainAuthority.read() else { throw JournalError.identityMissing }
            _ = try authority.recover(from: data)
            let result = try authority.observe(DeviceClock.read())
            try KeychainAuthority.update(authority)
            try markIdentity(in: directory)
            return result
        }
        notifyIfNeeded(snapshot)
        return snapshot
    }

    static func setNotifications(_ enabled: Bool) throws {
        try locked { _ in
            guard var authority = try KeychainAuthority.read() else { throw JournalError.identityMissing }
            authority.setNotifications(enabled)
            try KeychainAuthority.update(authority)
        }
    }

    private static func notifyIfNeeded(_ snapshot: SecureSnapshot?) {
        guard let snapshot, snapshot.notificationsEnabled, let hit = snapshot.newTodayHit else { return }
        // No future-win schedule or future payload exists. Only a committed,
        // clock-checked win may cause an alert; missed past wins remain in history.
        let content = UNMutableNotificationContent()
        content.title = "Today is a lucky day."
        content.body = "A little surprise is waiting in Someday."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "lucky-\(hit.day)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in
            // Notification delivery is optional. An error never reverses a win
            // or opens a new grant path; the protected collection is authoritative.
        }
    }
}
