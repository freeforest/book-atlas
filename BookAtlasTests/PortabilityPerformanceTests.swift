import Darwin
import XCTest
@testable import BookAtlas

final class PortabilityPerformanceTests: XCTestCase {
    func testFixedFictionalPerformanceBaselinesAtOneFiveAndTenThousandBooks() throws {
        for count in [1_000, 5_000, 10_000] {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let memoryBefore = residentMemoryBytes()
            let csvURL = directory.appendingPathComponent("import.csv")
            try writeCSV(count: count, to: csvURL)
            let coordinator = LibraryImportCoordinator()
            let repository = try BookRepository(
                databaseURL: directory.appendingPathComponent("import.sqlite")
            )

            let (_, parseSeconds) = try timed {
                try StreamingCSVParser().stream(url: csvURL) { _ in }
            }
            let (preview, previewSeconds) = try timed {
                try coordinator.prepare(url: csvURL, mapping: nil, repository: repository)
            }
            let (result, importSeconds) = try timed {
                try coordinator.execute(preview: preview, repository: repository)
            }
            XCTAssertEqual(result.imported, count)

            let records = try repository.exportRecords()
            let (_, markdownSeconds) = timed {
                LibraryMarkdownExporter.data(
                    records: records,
                    exportedAt: FictionalLibraryFixtures.timestamp
                )
            }
            let (_, csvSeconds) = timed {
                LibraryCSVExporter.data(records: records)
            }

            let backupURL = directory.appendingPathComponent("snapshot.bookatlasbackup")
            let backupCoordinator = LibraryBackupCoordinator()
            let (_, backupSeconds) = try timed {
                try backupCoordinator.backup(repository: repository, to: backupURL)
            }
            let liveURL = directory.appendingPathComponent("restored.sqlite")
            var live = try BookRepository(databaseURL: liveURL)
            let (_, restoreSeconds) = try timed {
                try backupCoordinator.restore(
                    backupURL: backupURL,
                    databaseURL: liveURL,
                    repository: &live,
                    recoveryDirectory: directory.appendingPathComponent("recovery")
                )
            }
            XCTAssertEqual(try live.allBooks().count, count)

            let memoryGrowth = max(0, residentMemoryBytes() - memoryBefore)
            XCTAssertLessThan(memoryGrowth, 768 * 1_024 * 1_024)
            print(
                """
                Prompt7 benchmark \(count): parse=\(parseSeconds)s preview=\(previewSeconds)s \
                import=\(importSeconds)s markdown=\(markdownSeconds)s csv=\(csvSeconds)s \
                backup=\(backupSeconds)s restore=\(restoreSeconds)s memory_growth=\(memoryGrowth)B
                """
            )
        }
    }

    func testNearLimitStreamingPreviewHasBoundedResidentMemoryAndCleansStaging() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let csvURL = directory.appendingPathComponent("near-limit.csv")
        let rowCount = 7_000
        let note = String(repeating: "x", count: 12_000)
        let handle = try FileHandle(forWritingTo: createFile(at: csvURL))
        try handle.write(contentsOf: Data(
            "format_version,title,author,note\n".utf8
        ))
        for index in 0 ..< rowCount {
            let row = "bookatlas-csv/1,NearLimit\(index),FictionalAuthor\(index),\(note)\n"
            try handle.write(contentsOf: Data(row.utf8))
        }
        try handle.close()
        let sourceBytes = try XCTUnwrap(
            csvURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        )
        XCTAssertGreaterThan(sourceBytes, 75 * 1_024 * 1_024)
        XCTAssertLessThan(sourceBytes, CSVParserLimits().maximumFileBytes)

        let repository = try BookRepository(
            databaseURL: directory.appendingPathComponent("library.sqlite")
        )
        let coordinator = LibraryImportCoordinator()
        let memoryBefore = currentResidentMemoryBytes()
        let peakBefore = residentMemoryBytes()
        let preview = try coordinator.prepare(
            url: csvURL,
            mapping: nil,
            repository: repository
        )
        let memoryGrowth = max(0, currentResidentMemoryBytes() - memoryBefore)
        let peakGrowth = max(0, residentMemoryBytes() - peakBefore)

        XCTAssertEqual(preview.totalRows, rowCount)
        XCTAssertEqual(preview.sampleRows.count, CSVParserLimits().previewRows)
        XCTAssertEqual(preview.issues.count, 0)
        XCTAssertTrue(preview.wasTruncated)
        XCTAssertTrue(FileManager.default.fileExists(atPath: preview.staging.recordsURL.path))
        XCTAssertLessThan(
            memoryGrowth,
            96 * 1_024 * 1_024,
            "Streaming preview must not retain the source plus a second unbounded row model"
        )
        XCTAssertLessThan(
            peakGrowth,
            96 * 1_024 * 1_024,
            "Peak growth must remain below a second full source-sized copy"
        )
        coordinator.discard(preview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: preview.staging.directoryURL.path))
        XCTAssertTrue(try repository.allBooks().isEmpty)
        print(
            "Prompt7 near-limit preview: source=\(sourceBytes)B memory_growth=\(memoryGrowth)B peak_growth=\(peakGrowth)B rows=\(rowCount)"
        )
    }

    @MainActor
    func testLargeParsingCanRunOffMainActorWhileMainActorRemainsResponsive() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let csvURL = directory.appendingPathComponent("responsive.csv")
        try writeCSV(count: 10_000, to: csvURL)
        let finished = expectation(description: "background parse")
        let mainActorResponded = expectation(description: "main actor response")

        Task.detached {
            _ = try StreamingCSVParser().stream(url: csvURL) { _ in }
            finished.fulfill()
        }
        Task { @MainActor in
            mainActorResponded.fulfill()
        }

        await fulfillment(of: [mainActorResponded], timeout: 1)
        await fulfillment(of: [finished], timeout: 10)
    }

    private func writeCSV(count: Int, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: createFile(at: url))
        try handle.write(contentsOf: Data("format_version,title,author\n".utf8))
        for index in 0 ..< count {
            try handle.write(contentsOf: Data(
                "bookatlas-csv/1,FictionalTitle\(String(index, radix: 36)),FictionalAuthor\(index)\n".utf8
            ))
        }
        try handle.close()
    }

    private func createFile(at url: URL) throws -> URL {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }

    private func timed<T>(_ operation: () throws -> T) rethrows -> (T, Double) {
        let start = ContinuousClock.now
        let value = try operation()
        let elapsed = start.duration(to: .now)
        return (value, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
    }

    private func residentMemoryBytes() -> Int {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return Int(usage.ru_maxrss)
    }

    private func currentResidentMemoryBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-PerformanceTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
