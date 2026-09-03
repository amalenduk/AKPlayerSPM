// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AKPlayer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AKPlayer",
            targets: ["AKPlayer"]
        )
    ],
    targets: [
        .target(
            name: "AKPlayer",
            dependencies: [],
            path: "Sources/AKPlayer"
        ),
        .testTarget(
            name: "AKPlayerTests",
            dependencies: ["AKPlayer"],
            path: "Tests/AKPlayerTests"
        )
    ]
)
