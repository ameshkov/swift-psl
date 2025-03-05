// swiftlint:disable large_tuple

import DomainParser  // Dashlane's implementation
import Foundation
import PublicSuffixList  // Our implementation
import TLDExtractSwift  // Gumob's implementation

// MARK: - Benchmark Configuration

// Number of domains to benchmark
// Use a smaller value for faster testing, or 0 for all domains
let domainLimit = 10000  // 0 means use all domains
let sampleSize = 3  // Number of runs for each implementation to average
let printInterval = 1000  // Print progress every X domains

// MARK: - Helper Functions

func readDomainsFromFile() -> [String] {
    let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Data")
        .appendingPathComponent("domains.txt")

    guard let data = try? Data(contentsOf: fileURL),
        let content = String(data: data, encoding: .utf8)
    else {
        fatalError("Failed to read domains file. Run download_domains.sh to download the data.")
    }

    var domains = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

    if domainLimit > 0 && domains.count > domainLimit {
        domains = Array(domains.prefix(domainLimit))
    }

    return domains
}

extension Date {
    var millisecondsSince1970: Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}

func formatDuration(_ milliseconds: Double) -> String {
    if milliseconds < 1000 {
        return String(format: "%.2f ms", milliseconds)
    } else {
        return String(format: "%.2f s", milliseconds / 1000)
    }
}

func formatOpsPerSecond(_ count: Int, _ milliseconds: Double) -> String {
    let opsPerSecond = Double(count) / (milliseconds / 1000)

    if opsPerSecond < 1000 {
        return String(format: "%.2f ops/s", opsPerSecond)
    } else if opsPerSecond < 1_000_000 {
        return String(format: "%.2f K ops/s", opsPerSecond / 1000)
    } else {
        return String(format: "%.2f M ops/s", opsPerSecond / 1_000_000)
    }
}

extension String {
    func padded(toWidth width: Int) -> String {
        if self.count >= width {
            return self
        }
        return self + String(repeating: " ", count: width - self.count)
    }
}

// Get system information to include in the report
func getSystemInfo() -> String {
    var sysinfo = ""

    // Get hardware model
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
    process.arguments = ["-n", "machdep.cpu.brand_string"]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let cpuInfo = String(data: data, encoding: .utf8) {
            sysinfo += "CPU: \(cpuInfo.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
    } catch {
        sysinfo += "CPU: Unable to retrieve CPU information\n"
    }

    // Get memory information
    let memoryProcess = Process()
    memoryProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
    memoryProcess.arguments = ["-n", "hw.memsize"]

    let memoryPipe = Pipe()
    memoryProcess.standardOutput = memoryPipe

    do {
        try memoryProcess.run()
        memoryProcess.waitUntilExit()

        let data = memoryPipe.fileHandleForReading.readDataToEndOfFile()
        if let memStr = String(data: data, encoding: .utf8),
            let memoryBytes = Int64(memStr.trimmingCharacters(in: .whitespacesAndNewlines))
        {  // swiftlint:disable:this opening_brace
            let memoryGB = Double(memoryBytes) / (1024 * 1024 * 1024)
            sysinfo += "Memory: \(String(format: "%.2f GB", memoryGB))\n"
        }
    } catch {
        sysinfo += "Memory: Unable to retrieve memory information\n"
    }

    // Get OS version
    let osProcess = Process()
    osProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sw_vers")

    let osPipe = Pipe()
    osProcess.standardOutput = osPipe

    do {
        try osProcess.run()
        osProcess.waitUntilExit()

        let data = osPipe.fileHandleForReading.readDataToEndOfFile()
        if let osInfo = String(data: data, encoding: .utf8) {
            let lines = osInfo.components(separatedBy: .newlines)
            for line in lines {
                sysinfo += "\(line)\n"
            }
        }
    } catch {
        sysinfo += "OS: Unable to retrieve OS information\n"
    }

    // Get Swift version
    let swiftProcess = Process()
    swiftProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    swiftProcess.arguments = ["--version"]

    let swiftPipe = Pipe()
    swiftProcess.standardOutput = swiftPipe

    do {
        try swiftProcess.run()
        swiftProcess.waitUntilExit()

        let data = swiftPipe.fileHandleForReading.readDataToEndOfFile()
        if let swiftInfo = String(data: data, encoding: .utf8) {
            sysinfo += "Swift: \(swiftInfo.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
    } catch {
        sysinfo += "Swift: Unable to retrieve Swift version\n"
    }

    return sysinfo
}

// MARK: - Benchmarking Code

// Benchmark swift-psl (our implementation)
func benchmarkSwiftPSL(
    domains: [String]
) -> (initTime: Double, processTime: Double, results: [String?]) {
    var results: [String?] = []
    results.reserveCapacity(domains.count)

    // Measure initialization time
    let initStartTime = Date().millisecondsSince1970

    // For swift-psl, initialization happens when we first access PublicSuffixList
    // This will trigger the static initializers that load the data files
    _ = PublicSuffixList.self

    let initEndTime = Date().millisecondsSince1970
    let initTime = Double(initEndTime - initStartTime)

    // Measure processing time
    var totalProcessTime: Double = 0

    for runIndex in 0..<sampleSize {
        let startTime = Date().millisecondsSince1970

        for (domainIndex, domain) in domains.enumerated() {
            let publicSuffix = PublicSuffixList.parsePublicSuffix(domain)?.suffix
            results.append(publicSuffix)

            if domainIndex % printInterval == 0 && domainIndex > 0 {
                print("SwiftPSL: Processed \(domainIndex) domains...")
            }
        }

        let endTime = Date().millisecondsSince1970
        totalProcessTime += Double(endTime - startTime)

        // Clear results between samples to save memory, except for the last run
        if runIndex < sampleSize - 1 {
            results.removeAll(keepingCapacity: true)
        }
    }

    return (initTime, totalProcessTime / Double(sampleSize), results)
}

// Benchmark Dashlane's SwiftDomainParser
func benchmarkSwiftDomainParser(
    domains: [String]
) -> (initTime: Double, processTime: Double, results: [String?]) {
    var results: [String?] = []
    results.reserveCapacity(domains.count)

    var initTime: Double = 0
    var totalProcessTime: Double = 0

    do {
        // Measure initialization time
        let initStartTime = Date().millisecondsSince1970

        let domainParser = try DomainParser()

        let initEndTime = Date().millisecondsSince1970
        initTime = Double(initEndTime - initStartTime)

        // Measure processing time
        for runIndex in 0..<sampleSize {
            let startTime = Date().millisecondsSince1970

            for (domainIndex, domain) in domains.enumerated() {
                let publicSuffix = domainParser.parse(host: domain)?.publicSuffix
                results.append(publicSuffix)

                if domainIndex % printInterval == 0 && domainIndex > 0 {
                    print("SwiftDomainParser: Processed \(domainIndex) domains...")
                }
            }

            let endTime = Date().millisecondsSince1970
            totalProcessTime += Double(endTime - startTime)

            // Clear results between samples to save memory, except for the last run
            if runIndex < sampleSize - 1 {
                results.removeAll(keepingCapacity: true)
            }
        }
    } catch {
        print("Error initializing SwiftDomainParser: \(error)")
    }

    return (initTime, totalProcessTime / Double(sampleSize), results)
}

// Benchmark gumob's TLDExtractSwift
func benchmarkTLDExtractSwift(
    domains: [String]
) -> (initTime: Double, processTime: Double, results: [String?]) {
    var results: [String?] = []
    results.reserveCapacity(domains.count)

    var initTime: Double = 0
    var totalProcessTime: Double = 0

    do {
        // Measure initialization time
        let initStartTime = Date().millisecondsSince1970

        let extractor = try TLDExtract(useFrozenData: true)

        let initEndTime = Date().millisecondsSince1970
        initTime = Double(initEndTime - initStartTime)

        // Measure processing time
        for runIndex in 0..<sampleSize {
            let startTime = Date().millisecondsSince1970

            for (domainIndex, domain) in domains.enumerated() {
                let publicSuffix = extractor.parse(domain)?.topLevelDomain
                results.append(publicSuffix)

                if domainIndex % printInterval == 0 && domainIndex > 0 {
                    print("TLDExtractSwift: Processed \(domainIndex) domains...")
                }
            }

            let endTime = Date().millisecondsSince1970
            totalProcessTime += Double(endTime - startTime)

            // Clear results between samples to save memory, except for the last run
            if runIndex < sampleSize - 1 {
                results.removeAll(keepingCapacity: true)
            }
        }
    } catch {
        print("Error initializing TLDExtractSwift: \(error)")
    }

    return (initTime, totalProcessTime / Double(sampleSize), results)
}

// MARK: - Main Execution Flow

print("Loading domains...")
let domains = readDomainsFromFile()
print("Loaded \(domains.count) domains")

print("\nStarting benchmark...")
print("Number of domains: \(domains.count)")
print("Sample size: \(sampleSize) runs per implementation\n")

// Run benchmarks
print("Benchmarking swift-psl...")
let swiftPSLResult = benchmarkSwiftPSL(domains: domains)

print("\nBenchmarking SwiftDomainParser...")
let swiftDomainParserResult = benchmarkSwiftDomainParser(domains: domains)

print("\nBenchmarking TLDExtractSwift...")
let tldExtractSwiftResult = benchmarkTLDExtractSwift(domains: domains)

// Calculate operations per second
let swiftPSLOpsPerSecond = formatOpsPerSecond(domains.count, swiftPSLResult.processTime)
let swiftDomainParserOpsPerSecond = formatOpsPerSecond(
    domains.count,
    swiftDomainParserResult.processTime
)
let tldExtractSwiftOpsPerSecond = formatOpsPerSecond(
    domains.count,
    tldExtractSwiftResult.processTime
)

// Calculate relative performance
let fastestProcessTime = min(
    swiftPSLResult.processTime,
    min(swiftDomainParserResult.processTime, tldExtractSwiftResult.processTime)
)
let swiftPSLRelative = fastestProcessTime / swiftPSLResult.processTime
let swiftDomainParserRelative = fastestProcessTime / swiftDomainParserResult.processTime
let tldExtractSwiftRelative = fastestProcessTime / tldExtractSwiftResult.processTime

// Print results
print("\n## Benchmark Results")
print("\nProcessed \(domains.count) domains with \(sampleSize) runs per implementation\n")

// Print system information
print("### System Information\n")
print("```")
print(getSystemInfo())
print("```\n")

// Generate a consolidated markdown table
print("### Performance Comparison\n")
let headers = [
    "Implementation", "Init Time", "Process Time", "Total Time", "Operations/Sec", "Relative Perf",
]
let headerWidths = [20, 15, 15, 15, 18, 15]

// Print table header
print(
    "| \(headers[0].padded(toWidth: headerWidths[0])) "
        + "| \(headers[1].padded(toWidth: headerWidths[1])) "
        + "| \(headers[2].padded(toWidth: headerWidths[2])) "
        + "| \(headers[3].padded(toWidth: headerWidths[3])) "
        + "| \(headers[4].padded(toWidth: headerWidths[4])) "
        + "| \(headers[5].padded(toWidth: headerWidths[5])) |"
)
print(
    "| \(String(repeating: "-", count: headerWidths[0])) "
        + "| \(String(repeating: "-", count: headerWidths[1])) "
        + "| \(String(repeating: "-", count: headerWidths[2])) "
        + "| \(String(repeating: "-", count: headerWidths[3])) "
        + "| \(String(repeating: "-", count: headerWidths[4])) "
        + "| \(String(repeating: "-", count: headerWidths[5])) |"
)

// Print table rows
// swiftlint:disable line_length
print(
    "| \("swift-psl".padded(toWidth: headerWidths[0])) "
        + "| \(formatDuration(swiftPSLResult.initTime).padded(toWidth: headerWidths[1])) "
        + "| \(formatDuration(swiftPSLResult.processTime).padded(toWidth: headerWidths[2])) "
        + "| \(formatDuration(swiftPSLResult.initTime + swiftPSLResult.processTime).padded(toWidth: headerWidths[3])) "
        + "| \(swiftPSLOpsPerSecond.padded(toWidth: headerWidths[4])) "
        + "| \(String(format: "%.3fx", swiftPSLRelative).padded(toWidth: headerWidths[5])) |"
)
print(
    "| \("SwiftDomainParser".padded(toWidth: headerWidths[0])) "
        + "| \(formatDuration(swiftDomainParserResult.initTime).padded(toWidth: headerWidths[1])) "
        + "| \(formatDuration(swiftDomainParserResult.processTime).padded(toWidth: headerWidths[2])) "
        + "| \(formatDuration(swiftDomainParserResult.initTime + swiftDomainParserResult.processTime).padded(toWidth: headerWidths[3])) "
        + "| \(swiftDomainParserOpsPerSecond.padded(toWidth: headerWidths[4])) "
        + "| \(String(format: "%.3fx", swiftDomainParserRelative).padded(toWidth: headerWidths[5])) |"
)
print(
    "| \("TLDExtractSwift".padded(toWidth: headerWidths[0])) "
        + "| \(formatDuration(tldExtractSwiftResult.initTime).padded(toWidth: headerWidths[1])) "
        + "| \(formatDuration(tldExtractSwiftResult.processTime).padded(toWidth: headerWidths[2])) "
        + "| \(formatDuration(tldExtractSwiftResult.initTime + tldExtractSwiftResult.processTime).padded(toWidth: headerWidths[3])) "
        + "| \(tldExtractSwiftOpsPerSecond.padded(toWidth: headerWidths[4])) "
        + "| \(String(format: "%.3fx", tldExtractSwiftRelative).padded(toWidth: headerWidths[5])) |"
)

// Print additional information
print("\nNote: Lower time is better. Higher operations per second is better.")
print(
    "The Relative Performance column shows how many times faster each implementation "
        + "is compared to the fastest one in terms of processing speed."
)
// swiftlint:enable line_length
// swiftlint:enable large_tuple
