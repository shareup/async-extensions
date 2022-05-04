// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "AsyncExtensions",
    platforms: [
        .macOS(.v11), .iOS(.v14), .tvOS(.v14), .watchOS(.v7),
    ],
    products: [
        .library(
            name: "AsyncExtensions",
            targets: ["AsyncExtensions"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AsyncExtensions",
            dependencies: []),
        .testTarget(
            name: "AsyncExtensionsTests",
            dependencies: ["AsyncExtensions"]),
    ]
)
