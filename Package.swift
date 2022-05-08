// swift-tools-version: 5.5

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
        .library(
            name: "AsyncTestExtensions",
            targets: ["AsyncTestExtensions"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AsyncExtensions",
            dependencies: []),
        .testTarget(
            name: "AsyncExtensionsTests",
            dependencies: ["AsyncExtensions", "AsyncTestExtensions"]),

            .target(
                name: "AsyncTestExtensions",
                dependencies: []),
    ]
)
