// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "needletail-irc",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NeedleTailIRC",
            targets: ["NeedleTailIRC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", .upToNextMajor(from: "1.22.0")),
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.65.0")),
        .package(url: "https://github.com/apple/swift-nio-extras.git", .upToNextMajor(from: "1.20.0")),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", .upToNextMajor(from: "2.25.0")),
        .package(url: "https://github.com/apple/swift-algorithms.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/needletails/needletail-logger.git", .upToNextMajor(from: "2.0.5")),
        .package(url: "https://github.com/needletails/needletail-algorithms.git", .upToNextMajor(from: "1.0.11")),
        .package(url: "https://github.com/vapor/jwt.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/apple/swift-testing.git", .upToNextMajor(from: "0.99.0")),
        .package(url: "https://github.com/orlandos-nl/BSON.git", .upToNextMajor(from: "8.1.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NeedleTailIRC",
            dependencies: [
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "NeedleTailLogger", package: "needletail-logger"),
                .product(name: "NeedleTailAlgorithms", package: "needletail-algorithms"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "BSON", package: "BSON")
            ]),
        .testTarget(
            name: "NeedleTailIRCTests",
            dependencies: [
                "NeedleTailIRC",
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "NeedleTailAlgorithms", package: "needletail-algorithms"),
                .product(name: "BSON", package: "BSON")
            ],
            resources: [.process("Resources")]
        )
    ]
)
