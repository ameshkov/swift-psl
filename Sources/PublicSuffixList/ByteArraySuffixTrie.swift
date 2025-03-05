import Foundation

/// A compact, memory-efficient suffix trie implementation that stores its node structure
/// in a single contiguous byte buffer. It supports:
///
///  - **Finding longest suffix** in a given string by efficiently traversing the trie structure
///  - **Serialization** to and from a `Data` object, making it easy to save or transmit
///
/// By storing the entire trie structure in a single `[UInt8]`, this suffix trie can be
/// written to disk or transferred across processes or networks with minimal overhead.
///
/// This implementation is specifically designed for suffix matching (particularly for domains
/// and URLs) with these key optimization strategies:
///  - Stores suffixes in a consistent order for predictable results
///  - Searches from longest to shortest possible suffixes (reversed approach)
///  - Early termination once a matching suffix is found
///  - Efficient byte-level processing with UTF-8 encoding
///
/// **Key highlights**:
///  - Each node's children and flags are packed in a compact format
///  - Words are limited to ASCII characters for simplicity and tight packing
///  - Because all data is in a single contiguous buffer, lookups require no dynamic allocations
///
/// **Note**:
///  - This implementation is optimized for read-mostly operations
///  - Ideal for static datasets that don't change frequently
public class ByteArraySuffixTrie {
    /// The raw byte array that holds all trie nodes.
    private var storage: [UInt8] = []

    /// The offset of the root node in `storage`.
    private var rootOffset: UInt32 = 0

    // MARK: - Public Initializers

    /// Initialize from an existing in-memory `SuffixTrie`.
    public init(from rootNode: SuffixTrie) {
        // We'll build up the storage dynamically, so start empty
        storage = []

        // Recursively build the root node
        rootOffset = buildNode(node: rootNode)
    }

    /// Initialize from existing `Data` (deserialize).
    public init(from data: Data) {
        // Just copy the bytes into storage
        self.storage = [UInt8](data)
        // The root node is at offset 0
        self.rootOffset = 0
    }

    // MARK: - Serialization

    /// Returns the number of underlying bytes.
    public var count: Int {
        return storage.count
    }

    /// Write to `Data`.
    public func write() -> Data {
        return Data(storage)
    }

    // MARK: - Find Longest Suffix

    /// Finds the longest matching suffix in `string` by reading from the end
    /// (i.e. reversed relative to the stored suffixes) in a single pass.
    ///
    /// - Parameter string: The string to search for a suffix in.
    /// - Returns: A tuple containing the longest matching suffix and its associated value, or nil if no match is found.
    public func findLongestSuffix(in string: String) -> (String, UInt8)? {
        let utf8 = string.utf8

        // Edge case: if the string is empty
        if utf8.isEmpty {
            if isEndOfSuffix(nodeOffset: rootOffset) {
                return ("", getValue(nodeOffset: rootOffset))
            }
            return nil
        }

        var currentNodeOffset = rootOffset
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
            guard
                let nextNodeOffset = findChildOffset(
                    parentOffset: currentNodeOffset,
                    char: byte
                )
            else {
                break  // no further match possible
            }
            currentNodeOffset = nextNodeOffset
            count += 1

            // If we've hit a valid suffix end, record the number of matched chars and the value
            if isEndOfSuffix(nodeOffset: currentNodeOffset) {
                bestMatchLength = count
                bestMatchValue = getValue(nodeOffset: currentNodeOffset)
            }
        }

        // If we never found any valid match, return nil
        if bestMatchLength == -1 {
            return nil
        }

        // bestMatchLength is how many characters from the end are matched.
        // So we extract that portion from the original string.
        let start = utf8.index(string.endIndex, offsetBy: -bestMatchLength)
        return (String(string[start..<string.endIndex]), bestMatchValue)
    }
}

// MARK: - Private Building/Reading Extensions

extension ByteArraySuffixTrie {
    /// Recursively build a node in `storage`, return the offset where it's placed.
    private func buildNode(node: SuffixTrie) -> UInt32 {
        // The offset where this node will begin in `storage`.
        let nodeStartOffset = UInt32(storage.count)

        // 1) childrenCount (1 byte)
        let childrenCount = UInt8(node.children.count)
        appendUInt8(childrenCount)

        // We need to store (char, childOffset) for each child.
        // But we don't know childOffset until we recursively build the child.
        // We'll do the typical "reserve space, build child, patch in offset" approach.

        let childrenStart = storage.count
        // For each child, we'll have 5 bytes: (1 for char, 4 for offset)
        storage.append(
            contentsOf: repeatElement(0, count: Int(childrenCount) * 5)
        )

        // 2) isEndOfSuffix flag (1 byte)
        appendUInt8(node.isEndOfSuffix ? 1 : 0)

        // 3) value (1 byte)
        appendUInt8(node.value)

        // Build children, patch them in
        let sortedChildren = node.children.sorted { $0.key < $1.key }
        for (index, (character, childNode)) in sortedChildren.enumerated() {
            let childOffset = buildNode(node: childNode)

            // Patch back (char, childOffset)
            let patchIndex = childrenStart + index * 5
            storage[patchIndex] = character

            let offsetBytes = withUnsafeBytes(of: childOffset.littleEndian, Array.init)
            for i in 0..<4 {
                storage[patchIndex + 1 + i] = offsetBytes[i]
            }
        }

        // Return where this node began
        return nodeStartOffset
    }

    /// Perform a binary search over the children’s `(char, offset)` pairs.
    private func findChildOffset(parentOffset: UInt32, char: UInt8) -> UInt32? {
        var cursor = Int(parentOffset)

        let childrenCount = readUInt8(at: cursor)
        cursor += 1

        // Each child has 5 bytes: 1 for char, 4 for offset.
        let start = cursor
        let childStride = 5

        var low = 0
        var high = Int(childrenCount) - 1

        while low <= high {
            let mid = (low + high) >> 1
            let childRecordOffset = start + mid * childStride

            let childChar = storage[childRecordOffset]
            if childChar == char {
                return readUInt32(at: childRecordOffset + 1)
            } else if childChar < char {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return nil
    }

    /// Read the isEndOfSuffix flag for a node at `nodeOffset`.
    private func isEndOfSuffix(nodeOffset: UInt32) -> Bool {
        var cursor = Int(nodeOffset)

        // Skip children section
        let childrenCount = readUInt8(at: cursor)
        cursor += 1 + (Int(childrenCount) * 5)

        // Read isEndOfSuffix flag (1 byte)
        return readUInt8(at: cursor) == 1
    }

    /// Read the value for a node at `nodeOffset`.
    private func getValue(nodeOffset: UInt32) -> UInt8 {
        var cursor = Int(nodeOffset)

        // Skip children section
        let childrenCount = readUInt8(at: cursor)
        cursor += 1 + (Int(childrenCount) * 5)

        // Skip isEndOfSuffix flag
        cursor += 1

        // Read value (1 byte)
        return readUInt8(at: cursor)
    }
}

// MARK: - Private read/write numeric helpers

extension ByteArraySuffixTrie {
    private func appendUInt8(_ value: UInt8) {
        storage.append(value)
    }

    private func readUInt8(at index: Int) -> UInt8 {
        return storage[index]
    }

    private func readUInt32(at index: Int) -> UInt32 {
        // Manual bit-shift
        let byte0 = UInt32(storage[index])
        let byte1 = UInt32(storage[index + 1]) << 8
        let byte2 = UInt32(storage[index + 2]) << 16
        let byte3 = UInt32(storage[index + 3]) << 24
        return byte0 | byte1 | byte2 | byte3
    }
}
