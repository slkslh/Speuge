// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Speuge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Speuge",
            targets: ["Speuge"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Speuge",
            path: "Sources/Speuge"
        )
    ]
)
