// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [
    .library(name: "DellBridgeCore", targets: ["DellBridgeCore"]),
    .executable(name: "dellctl", targets: ["dellctl"]),
]

var targets: [Target] = [
    .target(name: "DellBridgeCore", linkerSettings: [.linkedFramework("CoreDisplay")]),
    .executableTarget(name: "dellctl", dependencies: ["DellBridgeCore"], linkerSettings: [.linkedFramework("CoreDisplay")]),
    .testTarget(name: "DellBridgeCoreTests", dependencies: ["DellBridgeCore"], linkerSettings: [.linkedFramework("CoreDisplay")]),
]

#if os(macOS)
products.append(.executable(name: "DellBridge", targets: ["DellBridgeApp"]))
targets.append(.executableTarget(name: "DellBridgeApp", dependencies: ["DellBridgeCore"], linkerSettings: [.linkedFramework("CoreDisplay")]))
#endif

let package = Package(
    name: "DellBridge",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    targets: targets
)
