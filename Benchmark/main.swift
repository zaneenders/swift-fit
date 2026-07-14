import Foundation
import SwiftFit

// Benchmark: parse all .fit files from activities/ repeatedly, measure throughput.
// Usage: swift run -c release SwiftFitBenchmark [iterations] [path-to-activities]

let args = CommandLine.arguments
let iterations = args.count > 1 ? Int(args[1]) ?? 5 : 5
let dir = args.count > 2 ? args[2] : "activities"

let fm = FileManager.default
let fileNames = (try? fm.contentsOfDirectory(atPath: dir))?
    .filter { $0.hasSuffix(".fit") }
    .sorted() ?? []

guard !fileNames.isEmpty else {
    print("ERROR: no .fit files in \(dir)"); exit(1)
}

// Preload everything into memory (I/O excluded from timing).
let preloaded: [(String, Data)] = fileNames.compactMap { name in
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(name)")) else {
        print("WARNING: cannot read \(name)"); return nil
    }
    return (name, data)
}
let totalBytes = preloaded.reduce(0) { $0 + $1.1.count }

print("=== SwiftFit Benchmark ===")
print("Files:  \(preloaded.count)")
print("Data:   \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))")
print("Rounds: \(iterations)")
print()

var bestMbps  = 0.0
var worstMbps = Double.infinity
var totalElapsed: Double = 0

for round in 1...iterations {
    var messages = 0
    var errors   = 0

    let start = CFAbsoluteTimeGetCurrent()
    for (_, fileData) in preloaded {
        do {
            messages += try FITFile(data: fileData).messages.count
        } catch {
            errors += 1
        }
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    let mb = Double(totalBytes) / 1_000_000.0
    let mbps = mb / elapsed

    bestMbps  = max(bestMbps, mbps)
    worstMbps = min(worstMbps, mbps)
    totalElapsed += elapsed

    print(
      "  round \(round)/\(iterations):  \(unsafe String(format: "%7.1f", mbps)) MB/s   \(messages) msgs   \(errors) errs   \(unsafe String(format: "%.2f", elapsed))s"
    )
}

let avgMbps = Double(totalBytes) / 1_000_000.0 / (totalElapsed / Double(iterations))
print()
print("  best:  \(unsafe String(format: "%.1f", bestMbps)) MB/s")
print("  worst: \(unsafe String(format: "%.1f", worstMbps)) MB/s")
print("  avg:   \(unsafe String(format: "%.1f", avgMbps)) MB/s")
