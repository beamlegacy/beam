// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MockHttpServer",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "MockHttpServer",
            targets: ["MockHttpServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/httpswift/swifter.git", from: "1.5.0"),
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1"),
    ],
    targets: [
        .target(
            name: "MockHttpServer",
            dependencies: [
                .product(name: "Swifter", package: "swifter"),
                "Stencil",
            ],
            resources: [.copy("Resources")]
        ),
    ]
)
