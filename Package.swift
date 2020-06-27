// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "octahe",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser", from: "0.1.0"),
        .package(name: "swift-log", url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
        .package(name: "Mustache", url: "https://github.com/groue/GRMustache.swift", .upToNextMinor(from: "4.0.1")),
        .package(name: "Shout", url: "https://github.com/jakeheis/Shout", from: "0.5.6"),
        .package(name: "SwiftSerial", url: "https://github.com/yeokm1/SwiftSerial.git", from: "0.1.2"),
        .package(name: "Spinner", url: "https://github.com/dominicegginton/Spinner", from: "1.1.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "octahe",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Mustache", package: "Mustache"),
                .product(name: "Shout", package: "Shout"),
                .product(name: "SwiftSerial", package: "SwiftSerial"),
                .product(name: "Spinner", package: "Spinner")
            ],
            linkerSettings: [
                .unsafeFlags(
                    [
                        "-L/usr/local/opt/openssl@1.1/lib",
                        "-I/usr/local/opt/openssl@1.1/include"
                    ],
                    .when(platforms: [.macOS], configuration: .release)
                ),
            ]
        ),
        .testTarget(
            name: "octaheTests",
            dependencies: ["octahe"]),
    ]
)
