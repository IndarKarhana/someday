import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var export = false
    @State private var importing = false
    @State private var backup = JournalDocument(data: Data())
    @State private var pendingRestore: Data?
    @State private var confirmRestore = false
    @State private var odds = false
    @State private var widgetHelp = false
    @State private var notificationBusy = false
    @State private var readingBackup = false
    @State private var settingsError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                HStack { Eyebrow(text: "THE LITTLE DETAILS"); Spacer(); DismissButton() }
                Text("Quiet by design.").font(Paper.serif(39)).tracking(-1.5)
                Text("Just you, your phone, and a little chance.")
                    .font(.subheadline).foregroundStyle(Paper.muted)

                section("MAKE ROOM FOR POSSIBILITY") {
                    Button { widgetHelp = true } label: { row("Add a widget", symbol: "lock.rectangle", trailing: "arrow.up.right") }
                    Divider()
                    Toggle(isOn: Binding(get: { model.notificationsEnabled }, set: { value in
                        notificationBusy = true
                        Task {
                            await model.setNotifications(value)
                            if let message = model.errorMessage { settingsError = message; model.errorMessage = nil }
                            notificationBusy = false
                        }
                    })) {
                        Label("Lucky-day notifications", systemImage: "bell")
                            .font(.subheadline)
                    }.tint(Paper.ink).disabled(notificationBusy || model.journal == nil).padding(.vertical, 7)
                    Text("Optional, on-device alerts after a real win is checked. Open Someday or let iOS refresh its widget. Future wins are never calculated or scheduled in advance; iOS and Focus settings control delivery.")
                        .font(.caption).foregroundStyle(Paper.muted).lineSpacing(3)
                }

                section("KEEP YOUR STORY") {
                    Button {
                        Task {
                            do {
                                let data = try await Task.detached(priority: .userInitiated) { try SharedStorage.exportRecovery() }.value
                                backup = JournalDocument(data: data)
                                export = true
                            } catch { settingsError = error.localizedDescription }
                        }
                    } label: { row("Export a collection receipt", symbol: "square.and.arrow.up", trailing: "arrow.up.right") }
                        .disabled(model.journal == nil)
                    Divider()
                    Button { importing = true } label: { row(readingBackup ? "Authenticating your file…" : "Check a collection receipt", symbol: "square.and.arrow.down", trailing: "arrow.up.right") }
                        .disabled(readingBackup)
                    Text("Encrypted receipts can be checked only on this device against its protected collection. They are not portable backups: they cannot recreate a lost identity or transfer wins. Save individual cards as images for portable keepsakes.")
                        .font(.caption).foregroundStyle(Paper.muted).lineSpacing(3)
                }

                section("AN HONEST LITTLE APP") {
                    Button { odds = true } label: { row("The numbers & their odds", symbol: "sparkle", trailing: "chevron.right") }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        detail("No data collected", "No analytics, accounts, ads, tracking, or network requests. Sharing and receipt destinations are your choice.")
                        detail("One date, one result", "Reopening never rerolls a day. Missed days count only when continuous elapsed time can be verified. A detected restart or clock change starts a 24-hour verification pause; unverified gaps are skipped.")
                        detail("Device-bound protection", "The draw key and eligible-day record stay in this device’s protected Keychain. Imports cannot replace them, roll back time, or add wins. This discourages cheating; it cannot make a modified or compromised device trustworthy.")
                        detail("A keepsake, not a certificate", "Cards record a personal moment. They aren’t independently verified proof, and there’s no prize or purchase that changes your odds.")
                        if let journal = model.journal {
                            detail("Your day follows \(journal.timeZoneID.replacingOccurrences(of: "_", with: " "))", "Set when you started, so traveling won’t change your draws. Your story began \(journal.clock.label(for: journal.enrolledOn)).")
                        }
                    }.padding(.top, 9)
                }

                VStack(spacing: 9) {
                    PixelArt(color: Paper.muted).frame(width: 21, height: 21)
                    Text("someday").font(Paper.serif(25)).tracking(-0.8)
                    Text("VERSION 1.0 · MADE TO ASK LESS OF YOU")
                        .font(Paper.mono(8)).tracking(0.9).foregroundStyle(Paper.muted)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            }.padding(24)
        }
        .paperScreen()
        .buttonStyle(QuietButton())
        .sheet(isPresented: $odds) { OddsView() }
        .sheet(isPresented: $widgetHelp) { WidgetGuideView() }
        .fileExporter(isPresented: $export, document: backup, contentType: .json, defaultFilename: "Someday-receipt") { result in
            if case .failure(let error) = result { settingsError = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            readingBackup = true
            Task {
                defer { readingBackup = false }
                do {
                    let url = try result.get()
                    pendingRestore = try await Task.detached(priority: .userInitiated) {
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        let data = try BoundedFile.read(url)
                        try SharedStorage.validateRecovery(data)
                        return data
                    }.value
                    confirmRestore = true
                } catch { settingsError = error.localizedDescription }
            }
        }
        .confirmationDialog("Check this collection receipt?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Check receipt") {
                if let restored = pendingRestore { model.restore(restored) }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
                Text("This authenticates a collection receipt for this device. Your original identity, newer wins, and clock protections are preserved.")
        }
        .alert("Couldn’t complete that", isPresented: Binding(get: { settingsError != nil }, set: { if !$0 { settingsError = nil } })) {
            Button("OK") { settingsError = nil }
        } message: { Text(settingsError ?? "") }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: title)
            VStack(alignment: .leading, spacing: 13, content: content)
                .padding(19).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func row(_ title: String, symbol: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 21)
            Text(title).font(.subheadline)
            Spacer()
            Image(systemName: trailing).font(.caption).foregroundStyle(Paper.muted)
        }.frame(minHeight: 32)
    }

    private func detail(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(.caption, weight: .semibold))
            Text(text).font(.caption).foregroundStyle(Paper.muted).lineSpacing(3)
        }
    }
}
