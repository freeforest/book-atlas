import Darwin
import XCTest
@testable import BookAtlas

final class PortabilityPerformanceTests: XCTestCase {
    func testFixedFictionalPerformanceBaselinesAtOneFiveAndTenThousandBooks() throws {
        for count in [1_000, 5_000, 10_000] {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let memoryBefore = residentMemoryBytes()
            let csvData = makeCSV(count: count)
            let coordinator = LibraryImportCoordinator()
            let repository = try BookRepository(
                databaseURL: directory.appendingPathComponent("import.sqlite")
            )

            let (document, parseSeconds) = try timed {
                try StreamingCSVParser().parse(data: csvData)
            }
            let (preview, previewSeconds) = try timed {
                try coordinator.preview(
                    document: document,
                    mapping: .inferred(from: document.headers),
                    repository: repository
                )
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

    @MainActor
    func testLargeParsingCanRunOffMainActorWhileMainActorRemainsResponsive() async throws {
        let data = makeCSV(count: 10_000)
        let finished = expectation(description: "background parse")
        let mainActorResponded = expectation(description: "main actor response")

        Task.detached {
            _ = try StreamingCSVParser().parse(data: data)
            finished.fulfill()
        }
        Task { @MainActor in
            mainActorResponded.fulfill()
        }

        await fulfillment(of: [mainActorResponded], timeout: 1)
        await fulfillment(of: [finished], timeout: 10)
    }

    private func makeCSV(count: Int) -> Data {
        var value = "format_version,title,author\n"
        value.reserveCapacity(count * 64)
        for index in 0 ..< count {
            value += "bookatlas-csv/1,FictionalTitle\(String(index, radix: 36)),FictionalAuthor\(index)\n"
        }
        return Data(value.utf8)
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

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-PerformanceTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
