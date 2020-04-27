// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Future",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "Future", targets: ["Future"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Future", dependencies: [], path: "Sources"),
        .testTarget(name: "FutureTests", dependencies: ["Future"])
    ]
)
