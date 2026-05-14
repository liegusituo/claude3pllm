// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepSeekProxy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DeepSeekProxy",
            path: "Sources/DeepSeekProxy"
        ),
    ]
)
