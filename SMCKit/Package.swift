// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SMCKit",
    platforms: [.macOS(.v10_10)],
    products: [
        .library(name: "SMCKit", targets: ["SMCKit"]),
        .library(name: "SMC", targets: ["SMCKit"])
    ],
    targets: [
        .target(name: "SMCKit", path: ".", sources: ["SMC.swift", "SMCKitWrapper.swift"])
    ]
)
