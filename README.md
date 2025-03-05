# swift-psl

High performance Swift library for working with [public suffix list][publicsuffixlist]
and parsing hostnames relying on this information.

[publicsuffixlist]: https://publicsuffix.org/

## What Is A Public Suffix?

The Public Suffix List (PSL) is a cross-vendor initiative to provide
a definitive list of domain name suffixes. A "public suffix" is a domain under
which Internet users can directly register names. Some examples of public
suffixes are `.com`, `.co.uk`, and `pvt.k12.ma.us`.

When parsing hostnames, it's often necessary to identify not just the traditional top-level domain (TLD), but the entire public suffix (also known as effective TLD or eTLD). For example, while `.au` is a TLD, `com.au` is a public suffix because it represents the boundary at which domain registration occurs.

The most practical application is often identifying the "eTLD+1" - the public suffix plus one additional label. This concept is crucial for web security. For instance, browsers use eTLD+1 to enforce cookie access boundaries: `amazon.com.au` and `google.com.au` are considered separate domains that cannot access each other's cookies, while subdomains like `maps.google.com` and `www.google.com` can share cookies because they share the same eTLD+1 (`google.com`).

## What The Library Does

The library provides a **very fast** implementation of extracting a public
suffix (or an eTLD+1) from a hostname.

Existing implementation suffer from a number of issues:

* Slow lookups. See the [Benchmark](#benchmark) section for more details.

* Slow initialization. All of them try to be customizable and spend time on
  parsing PSL from the resources. It takes extra time and memory and causes a
  noticeable slowdown on first use.

* No updates. Most of the libraries use an old version of PSL and require you
  to have a newer PSL version as a dependency. `swift-psl` is automatically
  updated and released periodically so you just need to make sure you're using
  the last version of the package.

## How To Use The Library

To use the library, simply add the following to your `Package.swift`:

```swift
    dependencies: [
        .package(url: "https://github.com/ameshkov/swift-psl", .upToNextMinor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                .product(name: "PublicSuffixList", package: "swift-psl")
            ]),
    ]
```

Then use it like this:

```swift
import PublicSuffixList

if let (suffix, icann) = PublicSuffixList.parsePublicSuffix("example.co.uk") {
    // Prints "co.uk, icann: true"
    print("\(suffix), icann: \(icann)")
}

if let domain = PublicSuffixList.effectiveTLDPlusOne("example.co.uk") {
    // Prints "example.co.uk"
    print("\(domain)")
}
```

> [!NOTE]
> These functions do not normalize domain names. If you're dealing with
non-ASCII characters, make sure you encode them using something like
[Punycode][punycode] library.

[punycode]: https://github.com/gumob/PunycodeSwift

## Benchmark

This repository includes a [benchmark](Benchmark) to compare the performance
of `swift-psl` against other notable Swift implementations:

1. [SwiftDomainParser](https://github.com/Dashlane/SwiftDomainParser) by Dashlane
2. [TLDExtractSwift](https://github.com/gumob/TLDExtractSwift) by gumob

### System Information

```shell
swift-driver version: 1.115 CPU: Apple M1 Max
Memory: 32.00 GB
ProductName:  macOS
ProductVersion:  15.1
BuildVersion:  24B83

Swift: Apple Swift version 6.0 (swiftlang-6.0.0.9.10 clang-1600.0.26.2)
Target: arm64-apple-macosx15.0
```

### Performance Comparison

| Implementation       | Init Time       | Process Time    | Total Time      | Operations/Sec     | Relative Perf   |
| -------------------- | --------------- | --------------- | --------------- | ------------------ | --------------- |
| swift-psl            | 0.00 ms         | 4.33 ms         | 4.33 ms         | 2.31 M ops/s       | 1.000x          |
| SwiftDomainParser    | 7.00 ms         | 41.33 ms        | 48.33 ms        | 241.94 K ops/s     | 0.105x          |
| TLDExtractSwift      | 38.00 ms        | 2.26 s          | 2.30 s          | 4.42 K ops/s       | 0.002x          |

Note: Lower time is better. Higher operations per second is better.

The Relative Performance column shows how many times faster each implementation
is compared to the fastest one in terms of processing speed.
