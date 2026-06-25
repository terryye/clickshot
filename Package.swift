// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClickShot",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClickShot",
            path: "Sources/ClickShot"
        )
    ]
)
