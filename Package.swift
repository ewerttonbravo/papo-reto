// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PapoReto",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PapoRetoCore"),
        .executableTarget(name: "PapoReto", dependencies: ["PapoRetoCore"]),
        .testTarget(name: "PapoRetoCoreTests", dependencies: ["PapoRetoCore"]),
    ]
)
