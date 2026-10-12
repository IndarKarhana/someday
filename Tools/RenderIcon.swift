import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Development-only asset generator. The application ships the generated PNG,
// not this program. The geometry is original and uses no third-party artwork.
let edge = 1024
let context = CGContext(data: nil, width: edge, height: edge, bitsPerComponent: 8, bytesPerRow: edge * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.065, green: 0.075, blue: 0.065, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: edge, height: edge))
let pattern = ["0001000", "0001000", "0011100", "1111111", "0011100", "0001000", "0001000"]
let cell: CGFloat = 75
let start: CGFloat = (1024 - cell * 7) / 2
context.setFillColor(CGColor(red: 0.82, green: 0.94, blue: 0.44, alpha: 1))
for (y, row) in pattern.enumerated() {
    for (x, bit) in row.enumerated() where bit == "1" {
        context.fill(CGRect(x: start + CGFloat(x) * cell + 4, y: start + CGFloat(6 - y) * cell + 4,
                            width: cell - 8, height: cell - 8))
    }
}
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
guard CGImageDestinationFinalize(output) else { fatalError("Unable to write app icon") }
print("Rendered original 1024 × 1024 opaque app icon: \(destination.path)")
