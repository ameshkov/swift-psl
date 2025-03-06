import XCTest

@testable import PublicSuffixList

final class SuffixTrieTests: XCTestCase {
    // MARK: - Insertion Tests

    func testInsertAndFindSingleSuffix() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 10)

        // Test finding the suffix with value
        let result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 10)
    }

    func testInsertAndFindMultipleSuffixes() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 5)
        trie.insert(suffix: "co.uk", value: 7)

        // Test finding the suffixes with values
        let result1 = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result1?.0, "com")
        XCTAssertEqual(result1?.1, 5)

        let result2 = trie.findLongestSuffix(in: "example.co.uk") as (String, UInt8)?
        XCTAssertEqual(result2?.0, "co.uk")
        XCTAssertEqual(result2?.1, 7)
    }

    func testInsertDuplicateSuffix() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 1)
        trie.insert(suffix: "com", value: 2)  // Insert the same suffix with a different value

        let result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 2)  // Should be the latest value
    }

    // MARK: - Find Longest Suffix Tests

    func testFindLongestSuffix_EmptyString() {
        let trie = SuffixTrie()
        trie.insert(suffix: "", value: 42)

        let result = trie.findLongestSuffix(in: "") as (String, UInt8)?
        XCTAssertEqual(result?.0, "")
        XCTAssertEqual(result?.1, 42)
    }

    func testFindLongestSuffix_ExactMatch() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 255)  // Max UInt8 value

        let result = trie.findLongestSuffix(in: "com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 255)
    }

    func testFindLongestSuffix_WithPrefix() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 99)

        let result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.0, "com")
        XCTAssertEqual(result?.1, 99)
    }

    func testFindLongestSuffix_NoMatch() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 15)

        XCTAssertNil(trie.findLongestSuffix(in: "example.org") as (String, UInt8)?)
    }

    func testFindLongestSuffix_MultiplePossibleMatches() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 10)
        trie.insert(suffix: "co.uk", value: 20)
        trie.insert(suffix: "uk", value: 30)

        let result = trie.findLongestSuffix(in: "example.co.uk") as (String, UInt8)?
        XCTAssertEqual(result?.0, "co.uk")
        XCTAssertEqual(result?.1, 20)
    }

    func testFindLongestSuffix_PartialMatch() {
        let trie = SuffixTrie()
        trie.insert(suffix: "co.uk", value: 50)

        XCTAssertNil(trie.findLongestSuffix(in: "example.c") as (String, UInt8)?)
    }

    func testFindLongestSuffix_CaseSensitivity() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 60)

        XCTAssertNil(trie.findLongestSuffix(in: "example.COM") as (String, UInt8)?)
    }

    func testFindLongestSuffix_NestedSuffixes() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 5)
        trie.insert(suffix: "example.com", value: 10)

        let result1 = trie.findLongestSuffix(in: "test.example.com") as (String, UInt8)?
        XCTAssertEqual(result1?.0, "example.com")
        XCTAssertEqual(result1?.1, 10)

        let result2 = trie.findLongestSuffix(in: "test.com") as (String, UInt8)?
        XCTAssertEqual(result2?.0, "com")
        XCTAssertEqual(result2?.1, 5)
    }

    func testFindLongestSuffix_ComplexHierarchy() {
        let trie = SuffixTrie()
        trie.insert(suffix: "com", value: 1)
        trie.insert(suffix: "co.uk", value: 2)
        trie.insert(suffix: "gov.uk", value: 3)
        trie.insert(suffix: "ac.uk", value: 4)
        trie.insert(suffix: "org", value: 5)
        trie.insert(suffix: "net", value: 6)

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
        let trie = SuffixTrie()

        // Test with various values across the UInt8 range
        trie.insert(suffix: "com", value: 0)
        trie.insert(suffix: "org", value: 1)
        trie.insert(suffix: "net", value: 127)
        trie.insert(suffix: "io", value: 128)
        trie.insert(suffix: "dev", value: 254)
        trie.insert(suffix: "app", value: 255)

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

    func testUpdateValue() {
        let trie = SuffixTrie()

        // Insert a suffix with initial value
        trie.insert(suffix: "com", value: 10)

        // Verify the initial value
        var result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.1, 10)

        // Update the value for the same suffix
        trie.insert(suffix: "com", value: 20)

        // Verify the value was updated
        result = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
        XCTAssertEqual(result?.1, 20)
    }

    // MARK: - Performance Tests

    func testPerformance_InsertionWithValues() {
        measure {
            let trie = SuffixTrie()
            for i in 0..<10000 {
                let value = UInt8(i % 256)
                trie.insert(suffix: "com", value: value)
                trie.insert(suffix: "co.uk", value: value)
                trie.insert(suffix: "org", value: value)
                trie.insert(suffix: "net", value: value)
                trie.insert(suffix: "io", value: value)
            }
        }
    }

    func testPerformance_FindLongestSuffixWithValues() {
        // Set up a trie with several suffixes and values
        let trie = SuffixTrie()
        let suffixes = [
            "com", "co.uk", "gov.uk", "ac.uk", "org", "net", "io", "edu", "mil",
            "gov",
        ]
        for (index, suffix) in suffixes.enumerated() {
            trie.insert(suffix: suffix, value: UInt8(index % 256))
        }

        measure {
            for _ in 0..<10000 {
                _ = trie.findLongestSuffix(in: "example.com") as (String, UInt8)?
                _ = trie.findLongestSuffix(in: "example.co.uk") as (String, UInt8)?
                _ = trie.findLongestSuffix(in: "example.org") as (String, UInt8)?
                _ = trie.findLongestSuffix(in: "example.nonexistent") as (String, UInt8)?
            }
        }
    }
}
