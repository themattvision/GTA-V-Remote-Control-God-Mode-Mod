// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WineInputProbe",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "WineInputProbe", targets: ["WineInputProbe"]),
    ],
    targets: [
        .executableTarget(name: "WineInputProbe"),
    ]
)

