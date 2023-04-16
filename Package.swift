// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkingLayerNIO",
    platforms: [.macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NetworkingLayerNIO",
            targets: ["NetworkingLayerNIO"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/kevcodex/NetworkingLayer", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NetworkingLayerNIO",
            dependencies: [
                .product(name: "NetworkingLayerCore", package: "NetworkingLayer"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]),
        .testTarget(
            name: "NetworkingLayerNIOTests",
            dependencies: ["NetworkingLayerNIO"]),
    ]
)
