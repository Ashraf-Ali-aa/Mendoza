// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mendoza",
    dependencies: [
        .package(url: "https://github.com/tcamin/KeychainAccess.git", .branch("master")),
        .package(url: "https://github.com/Subito-it/Bariloche", .branch("master")),
        .package(url: "https://github.com/tcamin/Shout.git", .branch("subito")),
        .package(url: "https://github.com/tcamin/XcodeProj.git", .branch("Mendoza")),
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.0.0"),
    ],
    targets: [
        .target(
            name: "Mendoza",
            dependencies: ["Bariloche", "Shout", "XcodeProj", "KeychainAccess", "SourceKittenFramework"]
        ),
    ]
)
