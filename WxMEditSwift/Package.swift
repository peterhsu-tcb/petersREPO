// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WxMEditSwift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WxMEditSwift",
            targets: ["WxMEditSwift"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WxMEditSwift",
            dependencies: [],
            path: "Sources/WxMEditSwift",
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
            name: "WxMEditSwiftTests",
            dependencies: ["WxMEditSwift"],
            path: "Tests/WxMEditSwiftTests"
        )
    ]
)
