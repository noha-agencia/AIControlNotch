// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIControlNotch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AIControlNotch", targets: ["AIControlNotchApp"]),
        .executable(name: "aicontrolnotch-tap", targets: ["aicontrolnotch-tap"]),
        .library(name: "AIControlNotchCore", targets: ["AIControlNotchCore"]),
    ],
    targets: [
        .target(name: "AIControlNotchCore"),
        .executableTarget(name: "AIControlNotchApp", dependencies: ["AIControlNotchCore"]),
        .executableTarget(name: "aicontrolnotch-tap", dependencies: ["AIControlNotchCore"]),
        .testTarget(
            name: "AIControlNotchCoreTests",
            dependencies: ["AIControlNotchCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
