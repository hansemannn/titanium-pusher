// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "PusherSwift",
    products: [
        .library(name: "PusherSwift", targets: ["PusherSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/ashleymills/Reachability.swift.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMajor(from: "3.1.0")),
    ],
    targets: [
        .target(
            name: "PusherSwift",
            dependencies: [
                "Reachability",
                "Starscream",
            ],
            path: "Sources",
            exclude: ["PusherSwiftWithEncryption-Only"]
        ),
        .testTarget(
            name: "PusherSwiftTests",
            dependencies: ["PusherSwift"],
            path: "Tests",
            exclude: ["PusherSwiftWithEncryption-Only"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
