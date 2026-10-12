import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var journal: LuckyJournal?
    @Published private(set) var isLoading = true
    @Published private(set) var now = Date()
    @Published private(set) var phase: DrawPhase = .ready
    @Published var errorMessage: String?
    @Published private(set) var notificationsEnabled = false
    private var busy = false

    init() {
        // Remove schedules created by the pre-hardening prototype.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        reload(showLoading: true)
    }

    var today: LuckyNumber? { phase == .ready ? journal?.result(on: now) : nil }
    var pauseMessage: String? { phase.message }
    var dayNumber: Int { journal.map { $0.clock.dayNumber(on: now, enrolledOn: $0.enrolledOn) } ?? 1 }
    var qualifiedDays: Int { journal?.qualifiedDays ?? 0 }
    var hits: [LuckyHit] { (journal?.hits ?? []).reversed() }
    var todayKey: String { journal?.clock.key(for: now) ?? DayClock(timeZone: .current).key(for: now) }
    var nextRefreshDate: Date {
        switch phase {
        case .verifying(let until), .rateLimited(let until): return until
        case .unavailable: return Date().addingTimeInterval(300)
        default: break
        }
        return (journal?.clock ?? DayClock(timeZone: .current)).nextMidnight(after: now)
    }

    func begin() { reload(enroll: true, showLoading: true) }
    func refresh() { reload() }

    private func reload(enroll: Bool = false, showLoading: Bool = false) {
        guard !busy else { return }
        busy = true
        if showLoading { isLoading = true }
        Task {
            defer { busy = false; isLoading = false }
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try SharedStorage.load(enrollIfMissing: enroll)
                }.value
                if let snapshot { apply(snapshot) }
            } catch {
                // Keep already saved history visible, but never display an
                // unchecked current win after a secure-storage/read failure.
                phase = .unavailable
                errorMessage = error.localizedDescription
            }
        }
    }

    private func apply(_ snapshot: SecureSnapshot) {
        let changed = journal?.checkedThrough != snapshot.journal.checkedThrough || phase != snapshot.phase
        journal = snapshot.journal
        now = snapshot.date
        phase = snapshot.phase
        notificationsEnabled = snapshot.notificationsEnabled
        if changed { WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind) }
    }

    func restore(_ recoveryData: Data) {
        guard !busy else { errorMessage = JournalError.storageBusy.localizedDescription; return }
        busy = true
        isLoading = true
        Task {
            defer { busy = false; isLoading = false }
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try SharedStorage.restoreRecovery(recoveryData)
                }.value
                apply(snapshot)
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func setNotifications(_ enabled: Bool) async {
        if enabled {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                guard granted else {
                    errorMessage = "Notifications are off in iOS. You can enable them for Someday in Settings."
                    return
                }
            } catch { errorMessage = error.localizedDescription; return }
        }
        do {
            try await Task.detached(priority: .userInitiated) { try SharedStorage.setNotifications(enabled) }.value
            notificationsEnabled = enabled
            if !enabled { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
        } catch { errorMessage = error.localizedDescription }
    }
}

struct JournalDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= DrawAuthority.maximumArchiveBytes else { throw JournalError.invalidArchive }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
