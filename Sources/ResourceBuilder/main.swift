import Foundation
import PublicSuffixList
import Punycode

///
/// # ResourceBuilder
///
/// This executable is used to build binary trie data files from the Public Suffix List (PSL).
///
/// ## Usage
///
/// ```bash
/// swift run ResourceBuilder <path-to-public-suffix-list> <common-output-path> <negated-output-path> <asterisk-output-path>
/// ```
///
/// Example:
/// ```bash
/// # Download the latest PSL
/// curl -o /tmp/public_suffix_list.dat https://publicsuffix.org/list/public_suffix_list.dat
///
/// # Generate the binary trie data
/// swift run ResourceBuilder /tmp/public_suffix_list.dat ./Sources/PublicSuffixList/Resources/common.bin ./Sources/PublicSuffixList/Resources/negated.bin ./Sources/PublicSuffixList/Resources/asterisk.bin
/// ```
///
/// ## What It Does
///
/// 1. Parses the Public Suffix List file, filtering out comments and empty lines
/// 2. Separates ICANN and PRIVATE domains
/// 3. Categorizes rules into:
///    - Common rules (no special characters)
///    - Negated rules (rules starting with `!`)
///    - Asterisk rules (rules containing `*`)
/// 4. Handles punycode for international domain names
/// 5. Builds separate SuffixTries for each category
/// 6. Converts them to more efficient ByteArraySuffixTrie for storage and lookup
/// 7. Serializes the tries to binary files that can be embedded in the library
///
/// ## Output
///
/// The generated `.bin` files are binary representations of the Public Suffix List
/// that the PublicSuffixList library can load efficiently at runtime.
///

// MARK: - Argument handling

guard CommandLine.arguments.count == 5 else {
    print(
        "Usage: ResourceBuilder <path-to-public-suffix-list> "
            + "<common-output-path> <negated-output-path> <asterisk-output-path>"
    )
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let commonOutputPath = CommandLine.arguments[2]
let negatedOutputPath = CommandLine.arguments[3]
let asteriskOutputPath = CommandLine.arguments[4]

// MARK: - PSL Processing Functions

/// Represents a domain section in the Public Suffix List
enum DomainSection {
    case icann
    case privateSection
}

/// Represents the type of rule in the Public Suffix List
enum RuleType {
    case common
    case negated
    case asterisk
}

/// Structure with parsed PublicSuffixList
struct PublicSuffixList {
    var commonRules: [(suffix: String, isIcann: Bool)] = []
    var negatedRules: [(suffix: String, isIcann: Bool)] = []
    var asteriskRules: [(suffix: String, isIcann: Bool)] = []
}

/// Categorizes a rule and returns its type
func categorizeRule(_ rule: String) -> RuleType {
    if rule.hasPrefix("!") {
        return .negated
    } else if rule.contains("*") {
        return .asterisk
    } else {
        return .common
    }
}

/// Parses the Public Suffix List file, filtering out comments and empty lines,
/// and categorizes rules into different types.
func parsePublicSuffixList(
    from fileURL: URL
) throws -> PublicSuffixList {
    let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
    var list = PublicSuffixList()
    var currentSection: DomainSection = .icann

    for line in fileContents.components(separatedBy: .newlines) {
        // Skip empty lines
        guard !line.isEmpty else { continue }

        // Check for section headers
        if line.contains("===BEGIN PRIVATE DOMAINS===") {
            currentSection = .privateSection
            continue
        }

        // Skip comment lines (those that start with // or after a comment within a line)
        let commentStartRange = line.range(of: "//")
        let effectiveLine: String

        if let commentStart = commentStartRange {
            let lineBeforeComment = line[..<commentStart.lowerBound].trimmingCharacters(
                in: .whitespaces
            )
            if lineBeforeComment.isEmpty {
                continue  // Skip entire comment lines
            }
            effectiveLine = String(lineBeforeComment)
        } else {
            effectiveLine = line.trimmingCharacters(in: .whitespaces)
        }

        // Skip if line is now empty after stripping comments
        guard !effectiveLine.isEmpty else { continue }

        // The value to be stored in the trie - 0 for ICANN, 1 for PRIVATE
        let isIcann = currentSection == .icann

        // Categorize the rule
        let ruleType = categorizeRule(effectiveLine)

        // Convert to punycode if needed (for non-ASCII domains)
        let normalizedRule: String

        // Handle punycode conversion for international domain names
        if effectiveLine.contains(where: { !$0.isASCII }) {
            // Contains non-alphanumeric characters (other than .-!*), might need punycode conversion
            if effectiveLine.hasPrefix("!") || effectiveLine.hasPrefix("*") {
                // swiftlint:disable:next force_unwrapping
                let firstChar = String(effectiveLine.first!)
                // swiftlint:disable:next force_unwrapping
                normalizedRule = firstChar + String(effectiveLine.dropFirst()).idnaEncoded!
            } else {
                // swiftlint:disable:next force_unwrapping
                normalizedRule = effectiveLine.idnaEncoded!
            }
        } else {
            normalizedRule = effectiveLine
        }

        // Prepare the rule for insertion (prepend dot if needed)
        var processedRule = normalizedRule

        switch ruleType {
        case .common:
            // Prepend a dot and add to the common rules array
            let dotPrefixedSuffix =
                normalizedRule.hasPrefix(".") ? normalizedRule : "." + normalizedRule
            list.commonRules.append((dotPrefixedSuffix, isIcann))

        case .negated:
            // For !www.ck, add .www.ck to negated array
            // The exclamation mark is removed, and a dot is prepended
            processedRule = String(normalizedRule.dropFirst())  // Remove '!'
            let dotPrefixedSuffix =
                processedRule.hasPrefix(".") ? processedRule : "." + processedRule
            list.negatedRules.append((dotPrefixedSuffix, isIcann))

        case .asterisk:
            // For *.fk, add .fk to asterisk array
            // The wildcard is removed, and a dot is prepended
            processedRule = normalizedRule.replacingOccurrences(of: "*.", with: "")
            let dotPrefixedSuffix =
                processedRule.hasPrefix(".") ? processedRule : "." + processedRule
            list.asteriskRules.append((dotPrefixedSuffix, isIcann))
        }
    }

    return list
}

/// Builds a ByteArraySuffixTrie from a list of suffixes and writes it to the specified path
func buildAndWriteTrie(
    from suffixesWithTypes: [(suffix: String, isIcann: Bool)],
    to outputPath: String
) throws {
    print("Building SuffixTrie from \(suffixesWithTypes.count) suffixes...")
    let suffixTrie = SuffixTrie()
    for (suffix, isIcann) in suffixesWithTypes {
        // Insert 0 for ICANN, 1 for PRIVATE
        suffixTrie.insert(suffix: suffix, value: isIcann ? 0 : 1)
    }

    print("Converting to ByteArraySuffixTrie...")
    let byteArrayTrie = ByteArraySuffixTrie(from: suffixTrie)
    print("Size of the binary trie: \(byteArrayTrie.count) bytes")

    print("Writing binary trie to \(outputPath)...")
    let trieData = byteArrayTrie.write()
    try trieData.write(to: URL(fileURLWithPath: outputPath))
}

// MARK: - Main Logic

// Create input URL
let inputURL = URL(fileURLWithPath: inputPath)

do {
    // 1. Parse the suffixes from the file, categorizing by type
    print("Parsing Public Suffix List from \(inputPath)...")
    let list = try parsePublicSuffixList(from: inputURL)
    print("Found the following rules: ")
    print("\(list.commonRules.count) common rules")
    print("\(list.asteriskRules.count) asterisk rules")
    print("\(list.negatedRules.count) negated rules")

    // 2. Build and write the common trie
    print("\n--- Processing Common Rules ---")
    try buildAndWriteTrie(from: list.commonRules, to: commonOutputPath)
    print("Done! Common ByteArraySuffixTrie has been written to \(commonOutputPath)")

    // 3. Build and write the negated trie
    print("\n--- Processing Negated Rules ---")
    try buildAndWriteTrie(from: list.negatedRules, to: negatedOutputPath)
    print("Done! Negated ByteArraySuffixTrie has been written to \(negatedOutputPath)")

    // 4. Build and write the asterisk trie
    print("\n--- Processing Asterisk Rules ---")
    try buildAndWriteTrie(from: list.asteriskRules, to: asteriskOutputPath)
    print("Done! Asterisk ByteArraySuffixTrie has been written to \(asteriskOutputPath)")

    print("\nAll tries have been successfully generated!")
} catch {
    print("Error: \(error)")
    exit(1)
}
