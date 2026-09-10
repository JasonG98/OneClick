// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OneClickCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "OneClickCore", targets: ["OneClickCore"]),
    ],
    targets: [
        .target(
            name: "OneClickCore",
            path: "src",
            exclude: ["finder-extension", "app/OneClickApp.swift", "app/AppDelegate.swift", "app/views"],
            sources: ["shared", "app/stores"]
        ),
        .testTarget(
            name: "OneClickCoreTests",
            dependencies: ["OneClickCore"],
            path: "tests/core"
        ),
        .testTarget(
            name: "OneClickBehaviorTests",
            dependencies: ["OneClickCore"],
            path: "tests/behavior"
        ),
    ]
)
