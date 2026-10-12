import SwiftUI

@main
struct SomedayApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in model.refresh() }
                .task(id: "\(scenePhase)-\(String(describing: model.phase))-\(model.journal?.timeZoneID ?? TimeZone.current.identifier)") {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        let seconds = max(1, model.nextRefreshDate.timeIntervalSinceNow + 0.2)
                        do { try await Task.sleep(for: .seconds(seconds)) }
                        catch { return }
                        model.refresh()
                    }
                }
        }
    }
}
