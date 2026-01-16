// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GestureDetector",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .executable(name: "GestureDetector", targets: ["GestureDetector"])
    ],
    targets: [
        .executableTarget(
            name: "GestureDetector",
            path: "Sources/GestureDetector",
            exclude: ["Info.plist"]
        )
    ]
)
