// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FluentKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "FluentKit", targets: ["FluentKit"])
    ],
    targets: [
        .target(
            name: "FluentKit",
            path: "Sources/FluentKit"
        ),
        .testTarget(
            name: "FluentKitTests",
            dependencies: ["FluentKit"],
            path: "Tests/FluentKitTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
