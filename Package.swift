// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "needletail-irc",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NeedleTailIRC",
            targets: ["NeedleTailIRC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
        .package(url: "https://github.com/needletails/needletail-logger.git", from: "3.0.0"),
        .package(url: "https://github.com/needletails/needletail-algorithms.git", from: "2.0.3"),
        .package(url: "https://github.com/orlandos-nl/BSON.git", from: "8.1.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NeedleTailIRC",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "NeedleTailLogger", package: "needletail-logger"),
                .product(name: "NeedleTailAlgorithms", package: "needletail-algorithms"),
                .product(name: "BSON", package: "BSON")
            ],
        ),
        .testTarget(
            name: "NeedleTailIRCTests",
            dependencies: [
                "NeedleTailIRC",
                .product(name: "NeedleTailAlgorithms", package: "needletail-algorithms"),
                .product(name: "BSON", package: "BSON")
            ],

        )
    ]
)
