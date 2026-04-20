// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCommander",
    platforms: [
        .macOS(.v13)
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
            path: "Sources/SwiftCommander",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "SwiftCommanderTests",
            dependencies: ["SwiftCommander"],
            path: "Tests/SwiftCommanderTests"
        )
    ]
)
