// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mendoza",
    products: [
        .executable(name: "Mendoza", targets: ["Mendoza"]),
        .library(name: "MendozaCore", targets: ["MendozaCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tcamin/KeychainAccess.git", .branch("master")),
        .package(url: "https://github.com/Subito-it/Bariloche", .branch("master")),
        .package(url: "https://github.com/tcamin/Shout.git", .branch("subito")),
        .package(url: "https://github.com/tcamin/XcodeProj.git", .branch("Mendoza")),
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.0.1")),
        .package(url: "https://github.com/Ashraf-Ali-aa/Slang.git", .branch("slang-swift-package")),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", from: "0.1.3"),
    ],
    targets: [
        .target(
            name: "Mendoza",
            dependencies: ["MendozaCore"]
        ),
        .target(
            name: "MendozaCore",
            dependencies: ["Bariloche", "Shout", "XcodeProj", "KeychainAccess", "SourceKittenFramework", "ArgumentParser", "Slang", "SwiftToolsSupport"]
        ),
        .testTarget(
            name: "MendozaTests",
            dependencies: ["Mendoza"]
        ),
    ]
)
