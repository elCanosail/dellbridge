// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DellBridge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DellBridgeCore", targets: ["DellBridgeCore"]),
        .executable(name: "dellctl", targets: ["dellctl"]),
    ],
    targets: [
        .target(name: "DellBridgeCore"),
        .executableTarget(name: "dellctl", dependencies: ["DellBridgeCore"]),
        .testTarget(name: "DellBridgeCoreTests", dependencies: ["DellBridgeCore"]),
    ]
)
