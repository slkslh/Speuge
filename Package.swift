// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetworkSpeed",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NetworkSpeed",
            targets: ["NetworkSpeed"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NetworkSpeed",
            path: "Sources/NetworkSpeed"
        )
    ]
)
