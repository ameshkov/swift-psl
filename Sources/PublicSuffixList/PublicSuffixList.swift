import Foundation

/// A utility for working with domain names and Public Suffix List (PSL) rules
///
/// The Public Suffix List (PSL) is a list of domain suffixes under which Internet users
/// can directly register names. For example, ".com" and ".co.uk" are public suffixes.
/// This implementation uses the PSL to determine the effective top-level domain (eTLD)
/// and the registerable domain (eTLD+1) of a given hostname.
///
/// This implementation follows the rules defined by the Public Suffix List project:
/// https://publicsuffix.org/
public enum PublicSuffixList {
    // MARK: - Private Properties and Initialization

    /// ByteArraySuffixTrie loaded from the bundled common rules binary file
    nonisolated(unsafe) private static let commonTrie: ByteArraySuffixTrie = {
        guard
            let url = Bundle.module.url(
                forResource: "common",
                withExtension: "bin"
            ),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("Could not load common PSL trie")
        }
        return ByteArraySuffixTrie(from: data)
    }()

    /// ByteArraySuffixTrie loaded from the bundled negated rules binary file
    nonisolated(unsafe) private static let negatedTrie: ByteArraySuffixTrie = {
        guard
            let url = Bundle.module.url(
                forResource: "negated",
                withExtension: "bin"
            ),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("Could not load negated PSL trie")
        }
        return ByteArraySuffixTrie(from: data)
    }()

    /// ByteArraySuffixTrie loaded from the bundled asterisk rules binary file
    nonisolated(unsafe) private static let asteriskTrie: ByteArraySuffixTrie = {
        guard
            let url = Bundle.module.url(
                forResource: "asterisk",
                withExtension: "bin"
            ),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("Could not load asterisk PSL trie")
        }
        return ByteArraySuffixTrie(from: data)
    }()

    // MARK: - Domain Extraction Logic

    /// Extracts public suffix from the hostname.
    ///
    /// If a public suffix cannot be found, returns the TLD parsed from the
    /// hostname.
    ///
    /// **IMPORTANT:** this function does not normalize the domain name, i.e. you need
    /// to take care of the characters case and punycode encoding yourself.
    ///
    /// - Parameter hostname: The hostname to parse (e.g., "www.example.co.uk")
    /// - Returns: A tuple with the public suffix and a boolean indicating
    ///            whether it's an ICANN suffix
    ///
    /// icann is whether the public suffix is managed by the
    /// Internet Corporation for Assigned Names and Numbers. If not, the public
    /// suffix is either a privately managed domain (and in practice, not a top
    /// level domain) or an unmanaged top level domain (and not explicitly
    /// mentioned in the publicsuffix.org list). For example, "foo.org" and
    /// "foo.co.uk" are ICANN domains, "foo.dyndns.org" and "foo.blogspot.co.uk"
    /// are private domains and "cromulent" is an unmanaged top level domain.
    ///
    /// Use cases for distinguishing ICANN domains like "foo.com" from private
    /// domains like "foo.appspot.com" can be found at
    /// https://wiki.mozilla.org/Public_Suffix_List/Use_Cases
    public static func parsePublicSuffix(
        _ hostname: String
    ) -> (suffix: String, icann: Bool)? {
        // Due to how prefixes are stored in the tries, we need to prepend a dot
        // before searching for a suffix.
        let normalizedHostname = "." + hostname

        if let asteriskSuffix = asteriskTrie.findLongestSuffix(in: hostname) {
            let negatedSuffix = negatedTrie.findLongestSuffix(in: normalizedHostname)
            if negatedSuffix == nil {
                if let domain = closestNextDomain(hostname: hostname, suffix: asteriskSuffix.0) {
                    return (domain, asteriskSuffix.1 == 0)
                } else {
                    // This means we're dealing with a domain that
                    return (hostname, asteriskSuffix.1 == 0)
                }
            } else {
                return (String(asteriskSuffix.0.dropFirst()), asteriskSuffix.1 == 0)
            }
        }

        // Second, check for common rules
        if let commonSuffix = commonTrie.findLongestSuffix(in: normalizedHostname) {
            // Return the matching suffix without the leading dot
            return (String(commonSuffix.0.dropFirst()), commonSuffix.1 == 0)
        }

        // Third, check for asterisk rules
        // For asterisk rules, we need to check if any part of the domain matches
        // For example, if the rule is *.example.com, we need to check if our domain
        // ends with .example.com and has at least one label before it
        if let asteriskSuffix = asteriskTrie.findLongestSuffix(in: normalizedHostname) {
            // The domain must have at least one label before the matched suffix
            let parts = hostname.split(separator: ".")
            let suffixParts = asteriskSuffix.0.dropFirst().split(separator: ".")

            if parts.count > suffixParts.count {
                // There's at least one label before the matched suffix
                return (String(asteriskSuffix.0.dropFirst()), asteriskSuffix.1 == 0)
            }
        }

        // If no match found, extract the TLD (last component of the hostname)
        // Using lastIndex(of:) and substring extraction is more efficient than splitting
        if let lastDotIndex = hostname.lastIndex(of: ".") {
            let tld = hostname[hostname.index(after: lastDotIndex)...]
            if !tld.isEmpty {
                return (String(tld), false)
            }
        } else if !hostname.isEmpty {
            // No dots found but hostname is not empty, so the entire string is the TLD
            return (hostname, false)
        }

        return nil
    }

    /// Extracts eTLD+1 from the hostname taking public suffixes into account.
    ///
    /// If a public suffix cannot be found, returns just TLD+1.
    ///
    /// **IMPORTANT:** this function does not normalize the domain name, i.e. you need
    /// to take care of the characters case and punycode encoding yourself.
    ///
    /// - Parameter hostname: The hostname to parse (e.g., "www.example.co.uk")
    /// - Returns: The effective TLD+1 domain (e.g., "example.co.uk")
    public static func effectiveTLDPlusOne(_ hostname: String) -> String? {
        // Get the public suffix, prepend dot due to how the data is stored
        // in the suffix trie.
        guard let (suffix, _) = parsePublicSuffix(hostname) else {
            return nil
        }

        // If the hostname is exactly the suffix, return nil (no registerable domain)
        if hostname == suffix {
            return nil
        }

        // Find the eTLD+1 by looking for the domain component just before the suffix
        // Example: for "www.example.co.uk" with suffix ".co.uk", we want "example.co.uk"
        let withoutSuffix = hostname.dropLast(
            suffix.count
        )
        let components = withoutSuffix.split(separator: ".")

        if let lastComponent = components.last, !lastComponent.isEmpty {
            return "\(lastComponent).\(suffix)"
        }

        return nil
    }

    private static func closestNextDomain(hostname: String, suffix: String) -> String? {
        guard hostname.count > suffix.count else {
            return nil
        }

        // 1) Identify the substring before the suffix
        //    (this does not allocate new storage in Swift; it’s a "view" into the same buffer)
        let suffixStart = hostname.index(hostname.endIndex, offsetBy: -suffix.count)
        let prefix = hostname[..<suffixStart]  // type: Substring

        // If there's nothing before the suffix, there's no subdomain to remove.
        guard !prefix.isEmpty else {
            return nil
        }

        // 2) Find the last '.' in the prefix
        guard let dotIndex = prefix.lastIndex(of: ".") else {
            // No dot means something like "example.com" exactly, so no subdomain above it.
            return nil
        }

        // 3) The part after this dot is the next domain’s subdomain part
        let nextPartStart = prefix.index(after: dotIndex)
        guard nextPartStart < prefix.endIndex else {
            // There's a dot, but nothing follows it, e.g. "test." which doesn't form a valid domain
            return nil
        }

        // 4) Reuse the substring from nextPartStart up to prefix.endIndex
        //    and then append the original suffix (this is a final string creation).
        let nextDomain = prefix[nextPartStart...] + suffix

        return String(nextDomain)
    }
}
