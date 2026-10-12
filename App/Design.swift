import SwiftUI

enum Paper {
    static let background = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.09)
    static let muted = Color(red: 0.38, green: 0.40, blue: 0.36)
    static let line = Color(red: 0.83, green: 0.84, blue: 0.79)
    static let lime = Color(red: 0.82, green: 0.94, blue: 0.44)
    static let card = Color(red: 0.065, green: 0.075, blue: 0.065)
    static let white = Color(red: 0.97, green: 0.97, blue: 0.93)

    static func serif(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func mono(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Paper.muted
    var body: some View {
        Text(text).font(Paper.mono()).tracking(1.7).foregroundStyle(color)
    }
}

struct PrimaryButton: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 19)
            .foregroundStyle(light ? Paper.ink : Paper.white)
            .background(light ? Paper.lime : Paper.ink, in: RoundedRectangle(cornerRadius: 19))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    var dark = false
    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(dark ? Paper.white : Paper.ink)
                .frame(width: 44, height: 44)
                .background((dark ? Color.white : Paper.ink).opacity(0.07), in: Circle())
        }.accessibilityLabel("Close").buttonStyle(QuietButton())
    }
}

extension View {
    func paperScreen() -> some View {
        self.background(Paper.background.ignoresSafeArea()).foregroundStyle(Paper.ink).preferredColorScheme(.light)
    }
}
