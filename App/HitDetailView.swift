import SwiftUI
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct KeepsakeCard: View {
    let hit: LuckyHit
    let clock: DayClock
    var isSample = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isSample ? "SAMPLE · NOT A REAL HIT" : "A MOMENT THAT FOUND YOU")
                    .font(Paper.mono(8)).tracking(1.2)
                Spacer(minLength: 4)
                PixelArt(color: Paper.lime).frame(width: 13, height: 13)
            }.foregroundStyle(Paper.white.opacity(0.6))
            Spacer(minLength: 24)
            PixelArt(number: hit.number).frame(width: 106, height: 149)
                .accessibilityLabel("Lucky number \(hit.number.rawValue)")
            Spacer(minLength: 24)
            Text("Lucky day.").font(Paper.serif(40)).tracking(-1.3)
            Text(clock.label(for: hit.day)).font(.system(size: 13)).foregroundStyle(Paper.white.opacity(0.65)).padding(.top, 8)
            Rectangle().fill(Paper.white.opacity(0.18)).frame(height: 1).padding(.top, 26).padding(.bottom, 17)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hit.number.oddsLabel.uppercased()).font(Paper.mono(10)).tracking(1)
                    Text("DAY \(hit.dayNumber.formatted()) OF YOUR STORY").font(Paper.mono(7)).tracking(0.7).foregroundStyle(Paper.white.opacity(0.45))
                }
                Spacer()
                Text("someday").font(.system(size: 20, design: .serif)).tracking(-0.6)
            }
        }
        .padding(26).foregroundStyle(Paper.white).background(Paper.card)
        .accessibilityElement(children: .combine)
    }
}

struct HitDetailView: View {
    let hit: LuckyHit
    let clock: DayClock
    var isSample = false
    @State private var share: ShareItem?
    @State private var shareError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Eyebrow(text: isSample ? "A PEEK AT POSSIBILITY" : "FROM YOUR COLLECTION"); Spacer(); DismissButton() }
                KeepsakeCard(hit: hit, clock: clock, isSample: isSample)
                    .frame(height: 442).clipShape(RoundedRectangle(cornerRadius: 24))
                VStack(alignment: .leading, spacing: 10) {
                    Text(hit.number.name + ".").font(Paper.serif(28)).tracking(-0.7)
                    Text(isSample ? "This is a sample keepsake. A real one will have the date your number found you." : "A \(hit.number.oddsLabel.lowercased()) chance, on an otherwise ordinary day. This one is yours.")
                        .font(.subheadline).foregroundStyle(Paper.muted).lineSpacing(5)
                }
                Button(action: renderForSharing) {
                    Label(isSample ? "Share sample card" : "Share this lucky day", systemImage: "square.and.arrow.up")
                }.buttonStyle(PrimaryButton())
                Text(isSample ? "SAMPLE · NOT SAVED TO YOUR COLLECTION" : "A PERSONAL KEEPSAKE. NO PRIZE, JUST POSSIBILITY.")
                    .font(Paper.mono(8)).tracking(0.7).foregroundStyle(Paper.muted).frame(maxWidth: .infinity)
            }.padding(24).frame(maxWidth: 460).frame(maxWidth: .infinity)
        }
        .paperScreen()
        .sheet(item: $share) { item in ActivitySheet(url: item.url) }
        .alert("Couldn’t create the card", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("OK") { shareError = nil }
        } message: { Text(shareError ?? "") }
    }

    @MainActor private func renderForSharing() {
        let artwork = KeepsakeCard(hit: hit, clock: clock, isSample: isSample)
            .frame(width: 360, height: 470).environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 3
        guard let image = renderer.cgImage else {
            shareError = "Please try again."; return
        }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SomedayCards", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Only one generated file is retained; sharing doesn't accumulate images.
            let url = directory.appendingPathComponent("someday-card.png")
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                shareError = "Couldn’t prepare the image file."; return
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                shareError = "Couldn’t finish writing the image."; return
            }
            share = ShareItem(url: url)
        } catch { shareError = error.localizedDescription }
    }
}

private struct ShareItem: Identifiable { let id = UUID(); let url: URL }

#if canImport(UIKit)
private struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
// Used only by the macOS development preview renderer; the shipping target is iOS.
private struct ActivitySheet: View {
    let url: URL
    var body: some View { ShareLink(item: url) }
}
#endif
