// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GTAControlCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "GTAControlCore", targets: ["GTAControlCore"]),
    ],
    targets: [
        .target(name: "GTAControlCore"),
        .testTarget(name: "GTAControlCoreTests", dependencies: ["GTAControlCore"]),
    ]
)

