// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LipsumInAClick",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "LipsumInAClick", targets: ["LipsumInAClick"])
    ],
    targets: [
        .target(name: "LipsumCore"),
        .executableTarget(
            name: "LipsumInAClick",
            dependencies: ["LipsumCore"]
        ),
        .testTarget(
            name: "LipsumCoreTests",
            dependencies: ["LipsumCore"]
        )
    ]
)
