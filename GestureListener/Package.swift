// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GestureListener",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "GestureListener", targets: ["GestureListener"])
    ],
    targets: [
        .executableTarget(
            name: "GestureListener",
            path: "Sources/GestureListener"
        )
    ]
)
