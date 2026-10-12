// Development preview fixtures. Never included in either shipping target.
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var journal: LuckyJournal?
    @Published var isLoading = false
    @Published var phase: DrawPhase = .ready
    var pauseMessage: String? { phase.message }
    var qualifiedDays: Int { journal?.qualifiedDays ?? 0 }
    @Published var now: Date
    @Published var errorMessage: String?
    @Published var notificationsEnabled = false

    init(enrolled: Bool = true, yearsOfHistory: Bool = false) {
        let clock = DayClock(timeZone: .gmt)
        now = clock.date(for: "2026-10-11")!
        if enrolled {
            let first = clock.date(for: yearsOfHistory ? "2020-01-01" : "2026-10-11")!
            let value = try! DrawAuthority(reading: ClockReading(wall: first, uptime: 0), timeZone: .gmt)
            // Fixed visual fixture ONLY. This file is excluded from shipping.
            var json = try! JSONSerialization.jsonObject(with: value.protectedRepresentation()) as! [String: Any]
            json["secret"] = Data(0..<32).base64EncodedString()
            var fixture = try! DrawAuthority.fromProtectedRepresentation(JSONSerialization.data(withJSONObject: json))
            journal = try! fixture.observe(ClockReading(wall: now, uptime: now.timeIntervalSince(first))).journal
        }
    }

    var today: LuckyNumber? { phase == .ready ? journal?.result(on: now) : nil }
    var dayNumber: Int { journal.map { $0.clock.dayNumber(on: now, enrolledOn: $0.enrolledOn) } ?? 1 }
    var hits: [LuckyHit] { (journal?.hits ?? []).reversed() }
    var todayKey: String { journal?.clock.key(for: now) ?? "2026-10-11" }
    func begin() {}
    func restore(_ data: Data) {}
    func setNotifications(_ enabled: Bool) async {}
}

struct JournalDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

// No platform storage is accessed by design preview tools.
enum SharedStorage {
    static func exportRecovery() throws -> Data { throw JournalError.identityMissing }
    static func validateRecovery(_ data: Data) throws { throw JournalError.identityMissing }
}
