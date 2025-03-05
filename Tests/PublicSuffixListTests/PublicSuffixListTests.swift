import XCTest

@testable import PublicSuffixList

final class PublicSuffixListTests: XCTestCase {
    func testParsePublicSuffix() {
        // Test ICANN domain suffix parsing
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("example.com")?.suffix,
            "com"
        )
        XCTAssertTrue(
            PublicSuffixList.parsePublicSuffix("example.com")?.icann ?? false
        )
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("www.example.co.uk")?.suffix,
            "co.uk"
        )
        XCTAssertTrue(
            PublicSuffixList.parsePublicSuffix("www.example.co.uk")?.icann
                ?? false
        )

        // Test known public suffix managed privately
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("akadns.net")?.suffix,
            "akadns.net"
        )
        XCTAssertFalse(
            PublicSuffixList.parsePublicSuffix("akadns.net")?.icann ?? true
        )
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("somedomain.akadns.net")?.suffix,
            "akadns.net"
        )
        XCTAssertFalse(
            PublicSuffixList.parsePublicSuffix("somedomain.akadns.net")?.icann ?? true
        )

        // Test ICANN TLD suffix parsing
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("co.uk")?.suffix,
            "co.uk"
        )
        XCTAssertTrue(
            PublicSuffixList.parsePublicSuffix("co.uk")?.icann
                ?? false
        )

        // Test for domains that don't have a known public suffix
        // This should extract the TLD
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("example.notarealtld")?.suffix,
            "notarealtld"
        )
        XCTAssertFalse(
            PublicSuffixList.parsePublicSuffix("example.notarealtld")?.icann
                ?? true
        )

        // Test PRIVATE domain suffix parsing
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("example.cromulent")?.suffix,
            "cromulent"
        )
        XCTAssertFalse(
            PublicSuffixList.parsePublicSuffix("example.cromulent")?.icann ?? true
        )
        XCTAssertEqual(
            PublicSuffixList.parsePublicSuffix("cromulent")?.suffix,
            "cromulent"
        )
        XCTAssertFalse(
            PublicSuffixList.parsePublicSuffix("cromulent")?.icann
                ?? true
        )

        // Test empty hostname
        XCTAssertNil(PublicSuffixList.parsePublicSuffix(""))
    }

    func testEffectiveTLDPlusOne() {
        // Test standard TLD
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example.com"),
            "example.com"
        )
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("www.example.com"),
            "example.com"
        )
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("sub.www.example.com"),
            "example.com"
        )

        // Test multi-part public suffix
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example.co.uk"),
            "example.co.uk"
        )
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("www.example.co.uk"),
            "example.co.uk"
        )
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("sub.www.example.co.uk"),
            "example.co.uk"
        )

        // Test exact public suffix (should return nil as this isn't a registerable domain)
        XCTAssertNil(PublicSuffixList.effectiveTLDPlusOne("com"))
        XCTAssertNil(PublicSuffixList.effectiveTLDPlusOne("co.uk"))

        // Test for unknown TLD
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example.notarealtld"),
            "example.notarealtld"
        )

        // Test empty hostname
        XCTAssertNil(PublicSuffixList.effectiveTLDPlusOne(""))
    }

    // MARK: - Tests for Complex and Edge Cases

    func testComplexAndEdgeCases() {
        // Test domains with underscores
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example_domain.com"),
            "example_domain.com"
        )

        // Test domains with hyphens
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example-domain.co.uk"),
            "example-domain.co.uk"
        )

        // Test domains with special non-Latin characters
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("mañana.com"),
            "mañana.com"
        )

        // Test really long domain names (still valid)
        let longDomain = String(repeating: "a", count: 63) + ".com"
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne(longDomain),
            longDomain
        )
    }

    // MARK: - Test Unusual TLDs and Multi-Level Domain Rules

    func testUnusualTLDsAndRules() {
        // Test unusual but valid TLDs
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example.xyz"),
            "example.xyz"
        )

        // Test multi-level TLDs
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example.github.io"),
            "example.github.io"
        )

        // Test domains with very specific rules in some regions
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("example.k12.va.us"),
            "example.k12.va.us"
        )

        // Test private domains (assuming github.io is in private rules)
        XCTAssertEqual(
            PublicSuffixList.effectiveTLDPlusOne("username.github.io"),
            "username.github.io"
        )
    }

    // MARK: - Performance Tests

    func testPerformance_EffectiveTLDPlusOne() {
        // Measure performance of effectiveTLDPlusOne
        let domains = [
            "example.com",
            "www.example.co.uk",
            "test.example.org",
            "subdomain.example.net",
            "test.github.io",
            "example.notarealtld",
        ]

        measure {
            for _ in 0..<100 {
                for domain in domains {
                    _ = PublicSuffixList.effectiveTLDPlusOne(domain)
                }
            }
        }
    }

    func testPerformance_ParsePublicSuffix() {
        // Measure performance of parsePublicSuffix
        let domains = [
            "example.com",
            "www.example.co.uk",
            "test.example.org",
            "subdomain.example.net",
            "test.github.io",
            "example.notarealtld",
        ]

        measure {
            for _ in 0..<100 {
                for domain in domains {
                    _ = PublicSuffixList.parsePublicSuffix(domain)
                }
            }
        }
    }

    // MARK: - Comprehensive Public Suffix Test Cases

    func testPublicSuffixComprehensive() {
        // swiftlint:disable large_tuple

        // These tests are based on similar test cases from Go implementation
        // of publicsuffix-list and covers a wide range of real-world scenarios

        // Test cases structure: domain, expected suffix, expected ICANN flag
        let testCases: [(domain: String, expectedSuffix: String, expectedICANN: Bool)] = [
            // Empty string
            ("", "", false),

            // The .ao rules are:
            // ao
            // co.ao
            // ed.ao
            // edu.ao
            // gov.ao
            // gv.ao
            // it.ao
            // og.ao
            // org.ao
            // pb.ao
            ("ao", "ao", true),
            ("www.ao", "ao", true),
            ("pb.ao", "pb.ao", true),
            ("www.pb.ao", "pb.ao", true),
            ("www.xxx.yyy.zzz.pb.ao", "pb.ao", true),

            // The .ar rules are:
            // ar
            // bet.ar
            // com.ar
            // coop.ar
            // edu.ar
            // gob.ar
            // gov.ar
            // int.ar
            // mil.ar
            // musica.ar
            // mutual.ar
            // net.ar
            // org.ar
            // senasa.ar
            // tur.ar
            ("ar", "ar", true),
            ("www.ar", "ar", true),
            ("nic.ar", "ar", true),
            ("www.nic.ar", "ar", true),
            ("com.ar", "com.ar", true),
            ("www.com.ar", "com.ar", true),
            ("logspot.com.ar", "com.ar", true),
            ("zlogspot.com.ar", "com.ar", true),
            ("zblogspot.com.ar", "com.ar", true),

            // The .arpa rules
            // arpa
            // e164.arpa
            // home.arpa
            // in-addr.arpa
            // ip6.arpa
            // iris.arpa
            // uri.arpa
            // urn.arpa
            ("arpa", "arpa", true),
            ("www.arpa", "arpa", true),
            ("urn.arpa", "urn.arpa", true),
            ("www.urn.arpa", "urn.arpa", true),
            ("www.xxx.yyy.zzz.urn.arpa", "urn.arpa", true),

            // The relevant {kobe,kyoto}.jp rules are:
            // jp
            // *.kobe.jp
            // !city.kobe.jp
            // kyoto.jp
            // ide.kyoto.jp
            ("jp", "jp", true),
            ("kobe.jp", "jp", true),
            ("c.kobe.jp", "c.kobe.jp", true),
            ("b.c.kobe.jp", "c.kobe.jp", true),
            ("a.b.c.kobe.jp", "c.kobe.jp", true),
            ("city.kobe.jp", "kobe.jp", true),
            ("www.city.kobe.jp", "kobe.jp", true),
            ("kyoto.jp", "kyoto.jp", true),
            ("test.kyoto.jp", "kyoto.jp", true),
            ("ide.kyoto.jp", "ide.kyoto.jp", true),
            ("b.ide.kyoto.jp", "ide.kyoto.jp", true),
            ("a.b.ide.kyoto.jp", "ide.kyoto.jp", true),

            // The relevant .jp rules are:
            // ac.jp
            // 三重.jp (xn--ehqz56n.jp)
            // 京都.jp (xn--1lqs03n.jp)
            ("xn--ehqz56n.ac.jp", "ac.jp", true),
            ("xn--ehqz56n.jp", "xn--ehqz56n.jp", true),
            ("www.xn--ehqz56n.jp", "xn--ehqz56n.jp", true),
            ("xn--uc0atv.xn--1lqs03n.jp", "xn--1lqs03n.jp", true),
            ("xn--kpry57d.jp", "jp", true),

            // The .tw rules are:
            // tw
            // club.tw
            // com.tw
            // ebiz.tw
            // edu.tw
            // game.tw
            // gov.tw
            // idv.tw
            // mil.tw
            // net.tw
            // org.tw
            // mymailer.com.tw
            // url.tw
            // mydns.tw
            ("tw", "tw", true),
            ("aaa.tw", "tw", true),
            ("www.aaa.tw", "tw", true),
            ("xn--czrw28b.aaa.tw", "tw", true),
            ("edu.tw", "edu.tw", true),
            ("www.edu.tw", "edu.tw", true),

            // The .uk rules are:
            // uk
            // ac.uk
            // co.uk
            // gov.uk
            // ltd.uk
            // me.uk
            // net.uk
            // nhs.uk
            // org.uk
            // plc.uk
            // police.uk
            // *.sch.uk
            ("uk", "uk", true),
            ("aaa.uk", "uk", true),
            ("www.aaa.uk", "uk", true),
            ("mod.uk", "uk", true),
            ("www.mod.uk", "uk", true),
            ("sch.uk", "uk", true),
            ("mod.sch.uk", "mod.sch.uk", true),
            ("www.sch.uk", "www.sch.uk", true),
            ("co.uk", "co.uk", true),
            ("www.co.uk", "co.uk", true),
            ("blogspot.nic.uk", "uk", true),
            ("blogspot.sch.uk", "blogspot.sch.uk", true),

            // The .рф rules are
            // рф (xn--p1ai)
            ("xn--p1ai", "xn--p1ai", true),
            ("aaa.xn--p1ai", "xn--p1ai", true),
            ("www.xxx.yyy.xn--p1ai", "xn--p1ai", true),

            // The .bd rules are:
            // *.bd
            ("bd", "bd", false),
            ("www.bd", "www.bd", true),
            ("xxx.www.bd", "www.bd", true),
            ("zzz.bd", "zzz.bd", true),
            ("www.zzz.bd", "zzz.bd", true),
            ("www.xxx.yyy.zzz.bd", "zzz.bd", true),

            // The .ck rules are:
            // *.ck
            // !www.ck
            ("ck", "ck", false),
            ("www.ck", "ck", true),
            ("xxx.www.ck", "ck", true),
            ("zzz.ck", "zzz.ck", true),
            ("www.zzz.ck", "zzz.ck", true),
            ("www.xxx.yyy.zzz.ck", "zzz.ck", true),

            // The .myjino.ru rules (in the PRIVATE DOMAIN section) are:
            // myjino.ru
            // *.hosting.myjino.ru
            // *.landing.myjino.ru
            // *.spectrum.myjino.ru
            // *.vps.myjino.ru
            ("myjino.ru", "myjino.ru", false),
            ("aaa.myjino.ru", "myjino.ru", false),
            ("bbb.ccc.myjino.ru", "myjino.ru", false),
            ("hosting.ddd.myjino.ru", "myjino.ru", false),
            ("landing.myjino.ru", "myjino.ru", false),
            ("www.landing.myjino.ru", "www.landing.myjino.ru", false),
            ("spectrum.vps.myjino.ru", "spectrum.vps.myjino.ru", false),

            // The .uberspace.de rules (in the PRIVATE DOMAIN section) are:
            // *.uberspace.de
            ("uberspace.de", "de", true),
            ("aaa.uberspace.de", "aaa.uberspace.de", false),
            ("bbb.ccc.uberspace.de", "ccc.uberspace.de", false),

            // There are no .nosuchtld rules
            ("nosuchtld", "nosuchtld", false),
            ("foo.nosuchtld", "nosuchtld", false),
            ("bar.foo.nosuchtld", "nosuchtld", false),
        ]

        // Run all test cases
        for testCase in testCases {
            let result = PublicSuffixList.parsePublicSuffix(testCase.domain)

            let resultSuffix = result?.suffix ?? ""
            let resultICANN = result?.icann ?? false

            XCTAssertEqual(
                resultSuffix,
                testCase.expectedSuffix,
                "For domain '\(testCase.domain)': "
                    + "Expected suffix '\(testCase.expectedSuffix)' "
                    + "but got '\(resultSuffix)'"
            )

            XCTAssertEqual(
                resultICANN,
                testCase.expectedICANN,
                "For domain '\(testCase.domain)': "
                    + "Expected ICANN flag '\(testCase.expectedICANN)' "
                    + "but got '\(resultICANN)'"
            )
        }

        // swiftlint:enable large_tuple
    }
}
