// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "octahe",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "octahe",
            targets: ["octahe"]
        )
    ],
    dependencies: [
        .package(name: "swift-nio-ssl", url: "https://github.com/apple/swift-nio-ssl", from: "2.9.0"),
        .package(name: "swift-nio-ssl-support", url: "https://github.com/apple/swift-nio-ssl-support", from: "1.0.0"),
        .package(name: "swift-crypto", url: "https://github.com/apple/swift-crypto", from: "1.0.2"),
        .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser", from: "0.1.0"),
        .package(name: "swift-log", url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
        .package(name: "SwiftSerial", url: "https://github.com/yeokm1/SwiftSerial.git", from: "0.1.2"),
        .package(name: "Spinner", url: "https://github.com/dominicegginton/Spinner", from: "1.1.4"),
        .package(name: "Stencil", url: "https://github.com/stencilproject/Stencil", from: "0.13.0"),
        .package(name: "http-kit", url: "https://github.com/vapor/http.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "octahe",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftSerial", package: "SwiftSerial"),
                .product(name: "Spinner", package: "Spinner"),
                .product(name: "Stencil", package: "Stencil"),
                .product(name: "HTTPKit", package: "http-kit")
            ]
        ),
        .testTarget(
            name: "octaheTests",
            dependencies: ["octahe"]
        ),
    ]
)
