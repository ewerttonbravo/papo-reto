// swift-tools-version:6.0
import Foundation
import PackageDescription

// Fetched by scripts/fetch-deps.sh libs; the .app will bundle them in T09.
let sherpaLib = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("vendor/sherpa-onnx/lib").path

let package = Package(
    name: "PapoReto",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PapoRetoCore"),
        .systemLibrary(name: "CSherpaOnnx"),
        .target(
            name: "PapoRetoSherpa",
            dependencies: ["CSherpaOnnx"],
            linkerSettings: [.unsafeFlags(["-L\(sherpaLib)", "-Xlinker", "-rpath", "-Xlinker", sherpaLib])]
        ),
        .executableTarget(name: "PapoReto", dependencies: ["PapoRetoCore"]),
        .executableTarget(name: "papo-reto-bench", dependencies: ["PapoRetoCore", "PapoRetoSherpa", "CSherpaOnnx"]),
        .testTarget(name: "PapoRetoCoreTests", dependencies: ["PapoRetoCore"]),
    ]
)
