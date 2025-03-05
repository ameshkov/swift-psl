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

* Slow initialization. All of them try to be customizable and spend time on
  parsing PSL from the resources. It takes extra time and memory and causes a
  noticeable slowdown on first use.

* No updates. Most of the libraries use an old version of PSL and require you
  to have a newer PSL version as a dependency. `swift-psl` is automatically
  updated and released periodically so you just need to make sure you're using
  the last version of the package.

* Slow lookup. TODO: Add a bench table below

## How To Use The Library

To use the library, simply add the following to your `Package.swift`:

```swift
    dependencies: [
        .package(url: "https://github.com/ameshkov/swift-psl", .upToNextMinor(from: "1.0.0"))
    ],
```

Then use it like this:

```swift
import PublicSuffixList

if let (suffix, icann) = PublicSuffixList.parsePublicSuffix("example.co.uk") {
    // Prints "co.uk, icann: true"
    print("\(suffix), icann: \(icann)")
}

if let domain = PublicSuffixList.effectiveTLDPlusOne("example.co.uk") {
    // Prints "example.co.uk
    print("\(domain)")
}
```

**IMPORTANT:** This library is supposed to be used with ASCII characters.
If you're dealing with punycode domains, make sure you decode them first using something like [Punycode][punycode] library.

[punycode]: https://github.com/gumob/PunycodeSwift

## Internals

The library is using a Trie data structure to represent the public suffix list. The Trie is pre-built and loaded once at initialization.
