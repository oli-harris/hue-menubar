// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HueKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HueKit", targets: ["HueKit"])],
    targets: [
        .target(name: "HueKit", resources: [.copy("Resources")]),
        .testTarget(name: "HueKitTests", dependencies: ["HueKit"]),
    ]
)
