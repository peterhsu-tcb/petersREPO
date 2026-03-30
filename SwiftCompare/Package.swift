// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCompare",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SwiftCompare",
            targets: ["SwiftCompare"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwiftCompare",
            dependencies: [],
            path: "Sources/SwiftCompare"
        ),
        .testTarget(
            name: "SwiftCompareTests",
            dependencies: ["SwiftCompare"],
            path: "Tests/SwiftCompareTests"
        )
    ]
)
