// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ghrepoclean",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.2"),
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.2.4"),
        .package(url: "https://github.com/stairtree/NetworkClient.git", .branch("main")),
        .package(url: "https://github.com/vapor/async-kit.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ghrepoclean",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ConsoleKit", package: "console-kit"),
                .product(name: "NetworkClient", package: "NetworkClient"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "AsyncKit", package: "async-kit"),
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-concurrency"]),
                .unsafeFlags(["-parse-as-library"]), // SR-12683
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .testTarget(
            name: "ghrepocleanTests",
            dependencies: [
                .target(name: "ghrepoclean"),
            ]
        ),
    ]
)
