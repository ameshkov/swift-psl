# Public Suffix List Library Benchmark

This benchmark compares the performance of three Swift public suffix list implementations:

1. [swift-psl](https://github.com/ameshkov/swift-psl) - Our implementation
2. [SwiftDomainParser](https://github.com/Dashlane/SwiftDomainParser) - Dashlane's implementation
3. [TLDExtractSwift](https://github.com/gumob/TLDExtractSwift) - Gumob's implementation

## Setup

1. Download the domain list:

   ```bash
   chmod +x download_domains.sh
   ./download_domains.sh
   ```

2. Build the benchmark:

   ```bash
   swift build -c release
   ```

3. Run the benchmark:

   ```bash
   swift run -c release
   ```

## Customization

You can customize the benchmark by editing the constants at the top of `Sources/PSLBenchmark/main.swift`:

- `domainLimit`: Number of domains to test (0 means use all domains)
- `sampleSize`: Number of runs for each implementation to average
- `printInterval`: Print progress every X domains

## Results

The benchmark will output results in a markdown table format that can be easily copied to include in documentation.

Example output:

```shell
| Implementation       | Init Time       | Process Time    | Total Time      | Operations/Sec     | Relative Perf   |
| -------------------- | --------------- | --------------- | --------------- | ------------------ | --------------- |
| swift-psl            | 0.00 ms         | 4.33 ms         | 4.33 ms         | 2.31 M ops/s       | 1.000x          |
| SwiftDomainParser    | 7.00 ms         | 41.33 ms        | 48.33 ms        | 241.94 K ops/s     | 0.105x          |
| TLDExtractSwift      | 38.00 ms        | 2.26 s          | 2.30 s          | 4.42 K ops/s       | 0.002x          |
```
