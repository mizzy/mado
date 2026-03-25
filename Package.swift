// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "mado",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "mado",
            path: "Sources/mado"
        ),
    ]
)
