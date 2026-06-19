// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WarpClone",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WarpClone", targets: ["WarpClone"])
    ],
    targets: [
        .executableTarget(
            name: "WarpClone",
            path: "Sources/WarpClone"
        ),
        .testTarget(
            name: "WarpCloneTests",
            dependencies: ["WarpClone"],
            path: "Tests/WarpCloneTests"
        )
    ]
)
