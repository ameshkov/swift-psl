import XCTest

@testable import PublicSuffixList

final class ByteArraySuffixTrieTests: XCTestCase {
    // MARK: - Construction Tests

    func testInitFromSuffixTrieWithSingleSuffix() {
        // Create a SuffixTrie with a single suffix
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 10)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        // Test finding the suffix with value
        let result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 10)
    }

    func testInitFromSuffixTrieWithMultipleSuffixes() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 5)
        suffixTrie.insert(suffix: "co.uk", value: 7)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        // Test finding the suffixes with values
        let result1 = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result1?.0, "com")
        XCTAssertEqual(result1?.1, 5)

        let result2 = trie.findLongestSuffix(in: "example.co.uk") as (String, UInt8)?
        XCTAssertEqual(result2?.0, "co.uk")
        XCTAssertEqual(result2?.1, 7)
    }

    func testInitFromSuffixTrieWithDuplicateSuffix() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 1)
        // Insert the same suffix with a different value
        suffixTrie.insert(suffix: "com", value: 2)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 2)  // Should be the latest value
    }

    // MARK: - Find Longest Suffix Tests

    func testFindLongestSuffix_EmptyString() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "", value: 42)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let result = trie.findLongestSuffix(in: "") as (String, UInt8)?
        XCTAssertEqual(result?.0, "")
        XCTAssertEqual(result?.1, 42)
    }

    func testFindLongestSuffix_ExactMatch() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 255)  // Max UInt8 value

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let result = trie.findLongestSuffix(in: "com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 255)
    }

    func testFindLongestSuffix_WithPrefix() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 99)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 99)
    }

    func testFindLongestSuffix_NoMatch() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 15)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        XCTAssertNil(trie.findLongestSuffix(in: "example.org") as (String, UInt8)?)
    }

    func testFindLongestSuffix_MultiplePossibleMatches() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 10)
        suffixTrie.insert(suffix: "co.uk", value: 20)
        suffixTrie.insert(suffix: "uk", value: 30)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let result = trie.findLongestSuffix(in: "example.co.uk") as (String, UInt8)?
        XCTAssertEqual(result?.0, "co.uk")
        XCTAssertEqual(result?.1, 20)
    }

    func testFindLongestSuffix_PartialMatch() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "co.uk", value: 50)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        XCTAssertNil(trie.findLongestSuffix(in: "example.c") as (String, UInt8)?)
    }

    func testFindLongestSuffix_CaseSensitivity() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 60)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        XCTAssertNil(trie.findLongestSuffix(in: "example.COM") as (String, UInt8)?)
    }

    func testFindLongestSuffix_NestedSuffixes() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 5)
        suffixTrie.insert(suffix: "example.com", value: 10)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let result1 = trie.findLongestSuffix(in: "test.example.com") as (String, UInt8)?
        XCTAssertEqual(result1?.0, "example.com")
        XCTAssertEqual(result1?.1, 10)

        let result2 = trie.findLongestSuffix(in: "test.com") as (String, UInt8)?
        XCTAssertEqual(result2?.0, "com")
        XCTAssertEqual(result2?.1, 5)
    }

    func testFindLongestSuffix_ComplexHierarchy() {
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 1)
        suffixTrie.insert(suffix: "co.uk", value: 2)
        suffixTrie.insert(suffix: "gov.uk", value: 3)
        suffixTrie.insert(suffix: "ac.uk", value: 4)
        suffixTrie.insert(suffix: "org", value: 5)
        suffixTrie.insert(suffix: "net", value: 6)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let testCases = [
            ("example.com", "com", UInt8(1)),
            ("example.co.uk", "co.uk", UInt8(2)),
            ("example.gov.uk", "gov.uk", UInt8(3)),
            ("example.ac.uk", "ac.uk", UInt8(4)),
            ("example.org", "org", UInt8(5)),
            ("example.net", "net", UInt8(6)),
        ]

        for (input, expectedSuffix, expectedValue) in testCases {
            let result = trie.findLongestSuffix(in: input) as (String, UInt8)?
            XCTAssertEqual(result?.0, expectedSuffix)
            XCTAssertEqual(result?.1, expectedValue)
        }

        XCTAssertNil(trie.findLongestSuffix(in: "example.io") as (String, UInt8)?)
    }

    // MARK: - Value Tests

    func testSpecificValues() {
        let suffixTrie = SuffixTrie()

        // Test with various values across the UInt8 range
        suffixTrie.insert(suffix: "com", value: 0)
        suffixTrie.insert(suffix: "org", value: 1)
        suffixTrie.insert(suffix: "net", value: 127)
        suffixTrie.insert(suffix: "io", value: 128)
        suffixTrie.insert(suffix: "dev", value: 254)
        suffixTrie.insert(suffix: "app", value: 255)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        let testCases = [
            ("test.com", "com", UInt8(0)),
            ("test.org", "org", UInt8(1)),
            ("test.net", "net", UInt8(127)),
            ("test.io", "io", UInt8(128)),
            ("test.dev", "dev", UInt8(254)),
            ("test.app", "app", UInt8(255)),
        ]

        for (input, expectedSuffix, expectedValue) in testCases {
            let result = trie.findLongestSuffix(in: input) as (String, UInt8)?
            XCTAssertEqual(result?.0, expectedSuffix)
            XCTAssertEqual(result?.1, expectedValue)
        }
    }

    // MARK: - Serialization Tests

    func testSerializationAndDeserialization() {
        // Create and populate a SuffixTrie
        let suffixTrie = SuffixTrie()
        suffixTrie.insert(suffix: "com", value: 10)
        suffixTrie.insert(suffix: "co.uk", value: 20)
        suffixTrie.insert(suffix: "org", value: 30)

        // Create ByteArraySuffixTrie from the SuffixTrie
        let originalTrie = ByteArraySuffixTrie(from: suffixTrie)

        // Serialize to Data
        let data = originalTrie.write()

        // Deserialize to a new trie
        let deserializedTrie = ByteArraySuffixTrie(from: data)

        // Test that the deserialized trie works correctly
        let result1 = deserializedTrie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result1?.0, "com")
        XCTAssertEqual(result1?.1, 10)

        let result2 = deserializedTrie.findLongestSuffix(in: "example.co.uk") as (String, UInt8)?
        XCTAssertEqual(result2?.0, "co.uk")
        XCTAssertEqual(result2?.1, 20)

        let result3 = deserializedTrie.findLongestSuffix(in: "example.org") as (String, UInt8)?
        XCTAssertEqual(result3?.0, "org")
        XCTAssertEqual(result3?.1, 30)
    }

    // MARK: - Performance Tests

    func testPerformance_FindLongestSuffixWithValues() {
        // Set up a trie with several suffixes and values
        let suffixTrie = SuffixTrie()
        let suffixes = [
            "com", "co.uk", "gov.uk", "ac.uk", "org", "net", "io", "edu", "mil",
            "gov",
        ]
        for (index, suffix) in suffixes.enumerated() {
            suffixTrie.insert(suffix: suffix, value: UInt8(index % 256))
        }

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        measure {
            for _ in 0..<10000 {
                _ = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
                _ = trie.findLongestSuffix(in: "example.co.uk") as (String, UInt8)?
                _ = trie.findLongestSuffix(in: "example.org") as (String, UInt8)?
                _ = trie.findLongestSuffix(in: "example.nonexistent") as (String, UInt8)?
            }
        }
    }

    func testPerformance_SerializationAndDeserialization() {
        // Create a SuffixTrie with many suffixes
        let suffixTrie = SuffixTrie()
        for i in 0..<100 {
            let suffix = "suffix\(i).com"
            suffixTrie.insert(suffix: suffix, value: UInt8(i % 256))
        }

        // Create ByteArraySuffixTrie from the SuffixTrie
        let trie = ByteArraySuffixTrie(from: suffixTrie)

        measure {
            for _ in 0..<100 {
                // Serialize
                let data = trie.write()

                // Deserialize
                let newTrie = ByteArraySuffixTrie(from: data)

                // Quick verification
                _ = newTrie.count
            }
        }
    }
}
