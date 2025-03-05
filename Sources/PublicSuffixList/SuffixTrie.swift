/// A simple in-memory trie structure that stores reversed ASCII-based suffixes.
///
/// Typical usage:
///   let trie = SuffixTrie()
///   trie.insert(suffix: "com", value: 1)   // Internally inserts "moc" with value 1
///   trie.insert(suffix: "co.uk", value: 2) // Internally inserts "ku.oc" with value 2
///
/// Then:
///   trie.findLongestSuffix(in: "example.co.uk")  // -> ("co.uk", 2)
///   trie.findLongestSuffix(in: "test.com")       // -> ("com", 1)
///
public class SuffixTrie {
    /// Children keyed by ASCII character byte.
    var children: [UInt8: SuffixTrie] = [:]

    /// Flag indicating if this node represents the end of a valid reversed suffix.
    var isEndOfSuffix: Bool = false

    /// Value associated with this suffix, if it is an end of suffix.
    var value: UInt8 = 0

    public init() {}

    // MARK: - Insert (Reversed)

    /// Inserts a suffix into the trie by **storing it in reverse** internally, without extra array allocations.
    ///
    /// - Parameters:
    ///   - suffix: The suffix (ASCII only) to insert.
    ///   - value: The UInt8 value to associate with this suffix.
    public func insert(suffix: String, value: UInt8) {
        // We'll iterate from the end of suffix.utf8 to the beginning.
        let utf8 = suffix.utf8
        var current = self

        var i = utf8.endIndex
        // Move i backwards until it reaches utf8.startIndex
        while i > utf8.startIndex {
            utf8.formIndex(before: &i)
            let byte = utf8[i]
            // Insert into the trie
            if current.children[byte] == nil {
                current.children[byte] = SuffixTrie()
            }
            // swiftlint:disable:next force_unwrapping
            current = current.children[byte]!
        }

        // Mark the node corresponding to the first character
        current.isEndOfSuffix = true
        current.value = value
    }

    // MARK: - Find Longest Suffix (Reversed)

    /// Finds the longest matching suffix in `string` along with its associated value by reading from the end
    /// (i.e. reversed relative to the stored suffixes) in a single pass.
    ///
    /// - Parameter string: The string to search for a suffix in.
    /// - Returns: A tuple containing the longest matching suffix and its associated value, or nil if no match is found.
    public func findLongestSuffix(in string: String) -> (String, UInt8)? {
        let utf8 = string.utf8

        // Edge case: if the string is empty
        if utf8.isEmpty {
            return self.isEndOfSuffix ? ("", self.value) : nil
        }

        var current = self
        // Keep track of how many characters from the end matched a valid suffix so far
        var bestMatchLength = -1
        var bestMatchValue: UInt8 = 0

        // We'll just count how many characters we've processed from the end
        var count = 0

        var i = utf8.endIndex
        // Walk backward over the string. Each iteration is one character in reverse.
        while i > utf8.startIndex {
            utf8.formIndex(before: &i)
            let byte = utf8[i]

            // If there's a child that matches this reversed character,
            // move down one step in the trie
            guard let nextNode = current.children[byte] else {
                break  // no further match possible
            }
            current = nextNode
            count += 1

            // If we've hit a valid suffix end, record the number of matched chars and the value
            if current.isEndOfSuffix {
                bestMatchLength = count
                bestMatchValue = current.value
            }
        }

        // If we never found any valid match, return nil
        if bestMatchLength == -1 {
            return nil
        }

        // bestMatchLength is how many characters from the end are matched.
        // So we extract that portion from the original string.
        // Example: if bestMatchLength=6, we want the last 6 characters of string.
        let start = utf8.index(string.endIndex, offsetBy: -bestMatchLength)
        return (String(string[start..<string.endIndex]), bestMatchValue)
    }
}
