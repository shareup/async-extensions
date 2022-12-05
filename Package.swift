// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "AsyncExtensions",
    platforms: [
        .macOS(.v11), .iOS(.v14), .tvOS(.v14), .watchOS(.v7),
    ],
    products: [
        .library(
            name: "AsyncExtensions",
            targets: ["AsyncExtensions"]
        ),
        .library(
            name: "AsyncTestExtensions",
            targets: ["AsyncTestExtensions"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/shareup/synchronized.git",
            .upToNextMajor(from: "4.0.0")
        ),
    ],
    targets: [
        .target(
            name: "AsyncExtensions",
            dependencies: [
                .product(name: "Synchronized", package: "synchronized"),
            ]
        ),
        .testTarget(
            name: "AsyncExtensionsTests",
            dependencies: ["AsyncExtensions", "AsyncTestExtensions"]
        ),

        .target(
            name: "AsyncTestExtensions",
            dependencies: [
                .product(name: "Synchronized", package: "synchronized"),
            ]
        ),
        .testTarget(
            name: "AsyncTestExtensionsTests",
            dependencies: ["AsyncTestExtensions"]
        ),
    ]
)
