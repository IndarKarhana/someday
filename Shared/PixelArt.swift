import SwiftUI

/// Original geometric artwork. One Canvas per glyph; no image files or fonts.
struct PixelArt: View {
    var number: LuckyNumber? = nil
    var color: Color = .white
    var gap: CGFloat = 0.13

    private var rows: [String] {
        switch number {
        case .one: return ["00100", "01100", "00100", "00100", "00100", "00100", "01110"]
        case .two: return ["01110", "10001", "00001", "00010", "00100", "01000", "11111"]
        case .three: return ["11110", "00001", "00001", "01110", "00001", "00001", "11110"]
        case .four: return ["00010", "00110", "01010", "10010", "11111", "00010", "00010"]
        case .five: return ["11111", "10000", "10000", "11110", "00001", "00001", "11110"]
        case nil: return ["0001000", "0001000", "0011100", "1111111", "0011100", "0001000", "0001000"]
        }
    }

    var body: some View {
        Canvas { context, size in
            let width = rows[0].count
            let cell = min(size.width / CGFloat(width), size.height / CGFloat(rows.count))
            let origin = CGPoint(x: (size.width - CGFloat(width) * cell) / 2, y: (size.height - CGFloat(rows.count) * cell) / 2)
            for (y, row) in rows.enumerated() {
                for (x, value) in row.enumerated() where value == "1" {
                    let rect = CGRect(x: origin.x + CGFloat(x) * cell + cell * gap / 2,
                                      y: origin.y + CGFloat(y) * cell + cell * gap / 2,
                                      width: cell * (1 - gap), height: cell * (1 - gap))
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct PixelField: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 22
            for y in stride(from: CGFloat(8), to: size.height, by: step) {
                for x in stride(from: CGFloat(8), to: size.width, by: step) {
                    context.fill(Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.13)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
