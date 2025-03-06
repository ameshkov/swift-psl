// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PSLBenchmark",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // Our implementation
        .package(path: ".."),

        // SwiftDomainParser by Dashlane
        .package(url: "https://github.com/Dashlane/SwiftDomainParser.git", exact: "1.1.0"),

        // TLDExtractSwift by gumob
        .package(url: "https://github.com/gumob/TLDExtractSwift.git", exact: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PSLBenchmark",
            dependencies: [
                .product(name: "PublicSuffixList", package: "swift-psl"),
                .product(name: "DomainParser", package: "SwiftDomainParser"),
                .product(name: "TLDExtractSwift", package: "TLDExtractSwift"),
            ]
        )
    ]
)
