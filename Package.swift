// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [
    .library(name: "DellBridgeCore", targets: ["DellBridgeCore"]),
    .executable(name: "dellctl", targets: ["dellctl"]),
]

var targets: [Target] = [
    .target(name: "DellBridgeCore"),
    .executableTarget(name: "dellctl", dependencies: ["DellBridgeCore"]),
    .testTarget(name: "DellBridgeCoreTests", dependencies: ["DellBridgeCore"]),
]

#if os(macOS)
products.append(.executable(name: "DellBridge", targets: ["DellBridgeApp"]))
targets.append(.executableTarget(name: "DellBridgeApp", dependencies: ["DellBridgeCore"]))
#endif

let package = Package(
    name: "DellBridge",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    targets: targets
)
