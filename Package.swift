// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimpleNetwork",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SimpleNetwork",
            targets: ["SimpleNetwork"]
        ),
    ],
    targets: [
        .target(
            name: "SimpleNetwork",
            dependencies: []
        ),
        .testTarget(
            name: "SimpleNetworkTests",
            dependencies: ["SimpleNetwork"]
        ),
    ]
)
