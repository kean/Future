// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Future",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v4)
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
