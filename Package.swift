// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Future",
    products: [
        .library(name: "Future", targets: ["Future"])
    ],
    targets: [
        .target(name: "Future", path: "Sources")
    ]
)
