// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WarpClone",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WarpClone", targets: ["WarpClone"]),
        .executable(name: "warp", targets: ["WarpCLI"]),
        .library(name: "WarpCLICore", targets: ["WarpCLICore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "WarpClone",
            dependencies: [
                "WarpCLICore"
            ]
        ),
        .executableTarget(
            name: "WarpCLI",
            dependencies: [
                "WarpCLICore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "WarpCLICore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "WarpCLITests",
            dependencies: [
                "WarpCLICore"
            ]
        )
    ]
)
