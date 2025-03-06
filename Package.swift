// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-psl",
    products: [
        .library(
            name: "PublicSuffixList",
            targets: ["PublicSuffixList"]
        ),
        .executable(
            name: "ResourceBuilder",
            targets: ["ResourceBuilder"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/gumob/PunycodeSwift.git", exact: "3.0.0")
    ],
    targets: [
        .target(
            name: "PublicSuffixList",
            resources: [
                .copy("Resources/common.bin"),
                .copy("Resources/negated.bin"),
                .copy("Resources/asterisk.bin"),
                .copy("Resources/version.txt"),
            ]
        ),
        .executableTarget(
            name: "ResourceBuilder",
            dependencies: [
                "PublicSuffixList",
                .product(name: "Punycode", package: "PunycodeSwift"),
            ]
        ),
        .testTarget(
            name: "PublicSuffixListTests",
            dependencies: ["PublicSuffixList"]
        ),
    ]
)
