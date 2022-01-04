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
        .package(url: "https://github.com/Kitura/Kitura.git", from: "2.9.0"),
        .package(name: "KituraStencil", url: "https://github.com/Kitura/Kitura-StencilTemplateEngine.git", from: "1.11.1"),
        .package(name: "LoggingOSLog", url: "https://github.com/chrisaljoudi/swift-log-oslog.git", from: "0.2.1"),
    ],
    targets: [
        .target(
            name: "MockHttpServer",
            dependencies: ["Kitura", "KituraStencil", "LoggingOSLog"],
            resources: [.copy("Resources")]
        ),
    ]
)
