// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "JSONDiffCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JSONDiffCore", targets: ["JSONDiffCore"]),
    ],
    targets: [
        .target(
            name: "JSONDiffCore",
            path: "JSONDiff/JSONDiff",
            exclude: ["ContentView.swift", "JSONDiffApp.swift"],
            sources: ["JSONDiffEngine.swift"]
        ),
        .testTarget(
            name: "JSONDiffCoreTests",
            dependencies: ["JSONDiffCore"],
            path: "Tests/JSONDiffCoreTests"
        ),
    ]
)
