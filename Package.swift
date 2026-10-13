// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickSnip",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "QuickSnip", targets: ["QuickSnip"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "QuickSnip",
            dependencies: ["KeyboardShortcuts", .product(name: "Sparkle", package: "Sparkle")]
        ),
        .testTarget(
            name: "QuickSnipTests",
            dependencies: ["QuickSnip"]
        ),
    ]
)
