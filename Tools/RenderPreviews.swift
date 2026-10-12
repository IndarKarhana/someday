import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@main
struct RenderPreviews {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: "Previews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fresh = AppModel()
        let collector = AppModel(yearsOfHistory: true)
        let paused = AppModel(yearsOfHistory: true)
        paused.phase = .verifying(until: paused.now.addingTimeInterval(86400))
        try render(RootView().environmentObject(paused), name: "verification-pause", directory: directory)
        try render(RootView().environmentObject(fresh), name: "today", directory: directory)
        try render(RootView(initialTab: 1).environmentObject(fresh), name: "collection-empty", directory: directory)
        try render(RootView(initialTab: 1).environmentObject(collector), name: "collection", directory: directory)
        try render(WelcomeView().environmentObject(AppModel(enrolled: false)), name: "welcome", directory: directory)
        try render(OddsView(), name: "odds", directory: directory)
        try render(HitDetailView(hit: LuckyHit(day: "2026-10-11", number: .one, dayNumber: 842), clock: DayClock(timeZone: .gmt), isSample: true), name: "keepsake", directory: directory)
        try render(RootView().environmentObject(fresh).environment(\.dynamicTypeSize, .accessibility2), name: "today-accessibility", directory: directory)
        print("Rendered actual SwiftUI views at iPhone-sized bounds using macOS. These are design previews, not iOS simulator captures.")
    }

    @MainActor static func render<V: View>(_ view: V, name: String, directory: URL) throws {
        let content = view.frame(width: 393, height: 852)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
        // ScrollView wraps a native NSScrollView on macOS; ImageRenderer omits
        // those platform views. Host the real hierarchy before capturing it.
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: 393, height: 852)
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: 0, width: 393, height: 852),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.orderBack(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        window.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw RenderError.failed(name) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let image = bitmap.cgImage else { throw RenderError.failed(name) }
        let url = directory.appendingPathComponent("\(name).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw RenderError.failed(name) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.failed(name) }
        window.orderOut(nil)
        print("Rendered \(url.path)")
    }
}

enum RenderError: Error { case failed(String) }
