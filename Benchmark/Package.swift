// swift-tools-version:5.5
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
        .package(url: "https://github.com/Dashlane/SwiftDomainParser.git", from: "1.0.0"),

        // TLDExtractSwift by gumob
        .package(url: "https://github.com/gumob/TLDExtractSwift.git", from: "3.0.0"),
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
