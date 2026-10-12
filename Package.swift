// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SomedayCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "SomedayCore", targets: ["SomedayCore"]),
        .executable(name: "SomedayChecks", targets: ["SomedayChecks"]),
        .executable(name: "SecurityChecks", targets: ["SecurityChecks"])
    ],
    targets: [
        .target(name: "SomedayCore"),
        .testTarget(name: "SomedayCoreTests", dependencies: ["SomedayCore"]),
        .executableTarget(name: "SomedayChecks", dependencies: ["SomedayCore"], path: "Tools/CoreChecks"),
        .executableTarget(name: "SecurityChecks", dependencies: ["SomedayCore"], path: "Tools/SecurityChecks")
    ]
)
