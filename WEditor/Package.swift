// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WEditor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WEditor",
            targets: ["WEditor"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WEditor",
            dependencies: [],
            path: "Sources/WEditor",
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
            name: "WEditorTests",
            dependencies: ["WEditor"],
            path: "Tests/WEditorTests"
        )
    ]
)
