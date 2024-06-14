// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "needletail-irc",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NeedleTailIRC",
            targets: ["NeedleTailIRC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", .upToNextMajor(from: "1.20.0")),
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.65.0")),
        .package(url: "https://github.com/apple/swift-nio-extras.git", .upToNextMajor(from: "1.20.0")),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", .upToNextMajor(from: "2.25.0")),
        .package(url: "git@github.com:needle-tail/needletail-logger.git", .upToNextMajor(from: "1.0.2")),
        .package(url: "git@github.com:needle-tail/needletail-algorithms.git", .upToNextMajor(from: "1.0.1")),
        .package(url: "https://github.com/needle-tail/CypherTextKit.git", .upToNextMajor(from: "1.0.0-beta.2")),
        .package(url: "https://github.com/vapor/jwt.git", .upToNextMajor(from: "4.0.0"))
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
                .product(name: "NeedleTailLogger", package: "needletail-logger"),
                .product(name: "NeedleTailAlgorithms", package: "needletail-algorithms"),
                .product(name: "CypherMessaging", package: "CypherTextKit"),
                .product(name: "JWT", package: "jwt")
            ]),
        .testTarget(
            name: "NeedleTailIRCTests",
            dependencies: ["NeedleTailIRC"]),
    ]
)
