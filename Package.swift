// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "inlina",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "inlina",
            dependencies: [
                "KeyboardShortcuts",
                "HotKey",
            ],
            path: "inlina"
        ),
    ]
)
