import Testing
import Foundation
@testable import SwiftFit

/// Integration tests that parse real `.fit` files from the gitignored
/// `activities/` directory. Automatically disabled if the directory is missing
/// (e.g. on CI or a fresh checkout).
@Suite("Real FIT files")
struct FITRealFileTests {
    /// Locates the `activities/` directory by walking up from the test bundle.
    private static func activitiesDir() -> URL? {
        let here = URL(fileURLWithPath: #filePath)
        var url = here.deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = url.appendingPathComponent("activities")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    /// All `.fit` files in `activities/`, sorted for determinism.
    private static var allFiles: [URL] {
        guard let dir = activitiesDir() else { return [] }
        guard let urls = try? FileManager.default
            .contentsOfDirectory(at: dir,
                                 includingPropertiesForKeys: nil)
        else { return [] }
        return urls.filter { $0.pathExtension.lowercased() == "fit" }
                   .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func sampleFiles(_ n: Int) -> [URL] {
        Array(allFiles.prefix(n))
    }

    @Test(.disabled(if: FITRealFileTests.allFiles.isEmpty,
                    "no .fit files found in activities/"))
    func parseRealActivities() throws {
        let samples = Self.sampleFiles(8)
        for url in samples {
            let fit = try #require(try? FITFile(data: Data(contentsOf: url)),
                                   "failed to parse \(url.lastPathComponent)")
            #expect(fit.messages.count > 0,
                    "expected messages in \(url.lastPathComponent)")
            #expect(fit.messages.contains { $0.globalMessageNumber == 0 },
                    "expected a file_id message (mesg #0) in \(url.lastPathComponent)")
        }
    }

    @Test(.disabled(if: FITRealFileTests.allFiles.isEmpty,
                    "no .fit files found in activities/"))
    func messageCountsAreReasonable() throws {
        let url = Self.sampleFiles(1)[0]
        let fit = try FITFile(data: try Data(contentsOf: url))
        var counts: [UInt16: Int] = [:]
        for m in fit.messages { counts[m.globalMessageNumber, default: 0] += 1 }
        // Most activity files contain at least a file_id, activity, and records.
        #expect(counts.count > 3, "expected multiple distinct mesg types")
    }

    /// Parses every `.fit` file in `activities/`. Gated behind an environment
    /// variable so the default `swift test` stays fast; run with:
    ///   SWFITTFIT_FULL=1 swift test
    @Test(.disabled(if: ProcessInfo.processInfo.environment["SWFITTFIT_FULL"] == nil,
                    "set SWFITTFIT_FULL=1 to parse all activities"))
    func parseAllActivities() throws {
        let files = Self.allFiles
        for url in files {
            let fit = try #require(try? FITFile(data: Data(contentsOf: url)),
                                   "failed to parse \(url.lastPathComponent)")
            #expect(fit.messages.count > 0,
                    "no messages in \(url.lastPathComponent)")
        }
    }
}
