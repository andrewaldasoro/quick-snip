// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickSnip",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "QuickSnip", targets: ["QuickSnip"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0")
    ],
    targets: [
        .executableTarget(
            name: "QuickSnip",
            dependencies: ["KeyboardShortcuts"]
        ),
        .testTarget(
            name: "QuickSnipTests",
            dependencies: ["QuickSnip"]
        ),
    ]
)
