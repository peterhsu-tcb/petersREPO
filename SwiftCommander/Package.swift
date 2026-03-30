// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCommander",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SwiftCommander",
            targets: ["SwiftCommander"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwiftCommander",
            dependencies: [],
            path: "Sources/SwiftCommander"
        ),
        .testTarget(
            name: "SwiftCommanderTests",
            dependencies: ["SwiftCommander"],
            path: "Tests/SwiftCommanderTests"
        )
    ]
)
