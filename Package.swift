// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OneClickCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "OneClickCore", targets: ["OneClickCore"]),
    ],
    targets: [
        .target(name: "OneClickCore", path: "Shared/Core"),
        .testTarget(
            name: "OneClickCoreTests",
            dependencies: ["OneClickCore"],
            path: "Tests/CoreTests"
        ),
    ]
)
