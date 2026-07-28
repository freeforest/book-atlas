import Darwin
import SwiftUI
import XCTest
@testable import BookAtlas

final class GraphPerformanceTests: XCTestCase {
    func testFixedFictionalGraphBaselinesAtOneFiveAndTenThousandBooks() async throws {
        for count in [1_000, 5_000, 10_000] {
            let memoryBefore = currentResidentMemoryBytes()
            let repository = try BookRepository.inMemory()
            let centerID = UUID(
                uuidString: String(format: "10000000-0000-0000-0000-%012d", count)
            )!
            try repository.transaction {
                for index in 0 ..< count {
                    let id = index == 0
                        ? centerID
                        : UUID(
                            uuidString: String(
                                format: "20000000-0000-0000-%04d-%012d",
                                count / 1_000,
                                index
                            )
                        )!
                    _ = try repository.create(
                        BookDraft(
                            title: "虚构图谱书 \(String(index, radix: 36))",
                            author: "虚构规模作者 \(count)"
                        ),
                        id: id,
                        at: FictionalLibraryFixtures.timestamp
                    )
                }
            }
            let service = LibraryCatalogService(repository: repository)

            let totalStart = ContinuousClock.now
            let scene = try await service.localGraph(
                centerBookID: centerID,
                options: GraphBuildOptions()
            )
            let totalSeconds = totalStart.duration(to: .now).secondsValue
            XCTAssertEqual(scene.snapshot.nodes.count, GraphBuildOptions.defaultMaximumNodes)
            XCTAssertTrue(scene.snapshot.isLimited)
            XCTAssertLessThanOrEqual(
                scene.layout.completedIterations,
                GraphLayoutOptions().maximumIterations
            )

            let renderSeconds = await Self.firstRenderSeconds(scene: scene, catalog: service)
            let interactionSeconds = await Self.interactionSeconds(scene: scene, catalog: service)

            let reentryStart = ContinuousClock.now
            for _ in 0 ..< 5 {
                _ = try await service.localGraph(
                    centerBookID: centerID,
                    options: GraphBuildOptions()
                )
            }
            let reentrySeconds = reentryStart.duration(to: .now).secondsValue
            let memoryGrowth = max(0, currentResidentMemoryBytes() - memoryBefore)

            XCTAssertLessThan(totalSeconds, 30)
            XCTAssertLessThan(renderSeconds, 5)
            XCTAssertLessThan(interactionSeconds, 5)
            XCTAssertLessThan(reentrySeconds, 30)
            XCTAssertLessThan(memoryGrowth, 512 * 1_024 * 1_024)
            print(
                """
                Prompt8 benchmark \(count): query=\(scene.metrics.querySeconds)s \
                build=\(scene.metrics.projectionSeconds)s layout=\(scene.metrics.layoutSeconds)s \
                total=\(totalSeconds)s first_render=\(renderSeconds)s \
                interaction=\(interactionSeconds)s reentry5=\(reentrySeconds)s \
                memory_growth=\(memoryGrowth)B nodes=\(scene.snapshot.nodes.count) \
                edges=\(scene.snapshot.edges.count)
                """
            )
        }
    }

    @MainActor
    func testTenThousandBookProjectionRunsOffMainActorAndKeepsMainResponsive() async throws {
        let centerID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let service = try await Task.detached {
            let repository = try BookRepository.inMemory()
            try repository.transaction {
                for index in 0 ..< 10_000 {
                    let id = index == 0
                        ? centerID
                        : UUID(
                            uuidString: String(
                                format: "30000000-0000-0000-0001-%012d",
                                index
                            )
                        )!
                    _ = try repository.create(
                        BookDraft(
                            title: "虚构响应书 \(String(index, radix: 36))",
                            author: "虚构响应作者"
                        ),
                        id: id,
                        at: FictionalLibraryFixtures.timestamp
                    )
                }
            }
            return LibraryCatalogService(repository: repository)
        }.value
        let completed = expectation(description: "graph completed off main")
        let mainResponded = expectation(description: "main actor remained responsive")

        Task {
            _ = try await service.localGraph(
                centerBookID: centerID,
                options: GraphBuildOptions()
            )
            completed.fulfill()
        }
        Task { @MainActor in
            mainResponded.fulfill()
        }

        await fulfillment(of: [mainResponded], timeout: 1)
        await fulfillment(of: [completed], timeout: 30)
    }

    @MainActor
    private static func firstRenderSeconds(
        scene: GraphScene,
        catalog: any LibraryCataloging
    ) async -> Double {
        let store = GraphStore(catalog: catalog)
        store.load(centerBookID: scene.snapshot.centerBookID)
        await store.waitForPendingWork()
        let start = ContinuousClock.now
        let host = NSHostingView(
            rootView: LocalGraphView(
                store: store,
                defaultCenterBookID: scene.snapshot.centerBookID,
                openBook: { _ in }
            )
        )
        host.frame = CGRect(x: 0, y: 0, width: 1_100, height: 720)
        host.layoutSubtreeIfNeeded()
        host.display()
        return start.duration(to: .now).secondsValue
    }

    @MainActor
    private static func interactionSeconds(
        scene: GraphScene,
        catalog: any LibraryCataloging
    ) async -> Double {
        let store = GraphStore(catalog: catalog)
        store.load(centerBookID: scene.snapshot.centerBookID)
        await store.waitForPendingWork()
        let movable = scene.snapshot.nodes.first { !$0.isCenter }?.id
        let start = ContinuousClock.now
        for index in 0 ..< 100 {
            if let movable {
                store.selectNode(movable)
                store.moveNode(
                    movable,
                    to: CGPoint(x: 200 + index, y: 180 + index)
                )
            }
        }
        return start.duration(to: .now).secondsValue
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
}
