import CoreGraphics
import XCTest
@testable import BookAtlas

@MainActor
final class GraphStoreTests: XCTestCase {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000008101")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000008102")!

    func testLoadSelectMoveAndRecenterUpdateAccessibleState() async throws {
        let catalog = GraphCatalogProbe()
        let store = GraphStore(catalog: catalog)

        store.load(centerBookID: firstID)
        await store.waitForPendingWork()

        XCTAssertEqual(store.state, .content)
        XCTAssertEqual(store.centerBookID, firstID)
        XCTAssertEqual(store.selectedNode?.id, firstID)
        XCTAssertEqual(store.selectedRelations.count, 1)
        XCTAssertTrue(store.selectedRelations[0].explanations.contains("同作者：虚构作者"))

        store.selectNode(secondID)
        XCTAssertEqual(store.selectedNode?.id, secondID)
        store.moveNode(secondID, to: CGPoint(x: 321, y: 123))
        XCTAssertEqual(store.scene?.layout.positions[secondID], CGPoint(x: 321, y: 123))

        store.useSelectedNodeAsCenter()
        await store.waitForPendingWork()
        XCTAssertEqual(store.centerBookID, secondID)
        XCTAssertEqual(store.scene?.snapshot.centerBookID, secondID)
        XCTAssertEqual(store.selectedNode?.id, secondID)
    }

    func testDepthFilterAndResetTriggerFreshBuildOptions() async throws {
        let catalog = GraphCatalogProbe()
        let store = GraphStore(catalog: catalog)
        store.load(centerBookID: firstID)
        await store.waitForPendingWork()

        store.setDepth(.secondDegree)
        await store.waitForPendingWork()
        XCTAssertEqual(store.options.depth, .secondDegree)

        store.toggleRelationType(.sameAuthor)
        await store.waitForPendingWork()
        XCTAssertFalse(store.options.relationTypes.contains(.sameAuthor))

        store.resetView()
        await store.waitForPendingWork()
        let requests = await catalog.recordedOptions()
        XCTAssertEqual(requests.last?.depth, .secondDegree)
        XCTAssertFalse(try XCTUnwrap(requests.last).relationTypes.contains(.sameAuthor))
        XCTAssertGreaterThanOrEqual(requests.count, 4)
    }

    func testCancelledBuildReportsAccurateStateAndCanReenter() async throws {
        let catalog = GraphCatalogProbe(delayNanoseconds: 200_000_000)
        let store = GraphStore(catalog: catalog)
        store.load(centerBookID: firstID)
        XCTAssertEqual(store.state, .loading)

        store.cancel()
        await store.waitForPendingWork()
        XCTAssertEqual(store.state, .cancelled)
        XCTAssertEqual(store.statusMessage, "图谱构建已取消；书库未更改。")

        await catalog.setDelay(0)
        store.reload()
        await store.waitForPendingWork()
        XCTAssertEqual(store.state, .content)
        XCTAssertEqual(store.scene?.snapshot.centerBookID, firstID)
    }

    func testStaleCenterResultCannotOverwriteNewerCenter() async throws {
        let catalog = GraphCatalogProbe(
            perCenterDelay: [
                firstID: 180_000_000,
                secondID: 0
            ],
            ignoresCancellation: true
        )
        let store = GraphStore(catalog: catalog)

        store.load(centerBookID: firstID)
        store.load(centerBookID: secondID)
        await store.waitForPendingWork()
        try await Task.sleep(nanoseconds: 230_000_000)

        XCTAssertEqual(store.centerBookID, secondID)
        XCTAssertEqual(store.scene?.snapshot.centerBookID, secondID)
        XCTAssertEqual(store.state, .content)
    }

    func testEmptyMissingCenterAndDatabaseFailureHaveDistinctStates() async throws {
        let emptyCatalog = GraphCatalogProbe(returnsEmpty: true)
        let emptyStore = GraphStore(catalog: emptyCatalog)
        emptyStore.load(centerBookID: firstID)
        await emptyStore.waitForPendingWork()
        XCTAssertEqual(emptyStore.state, .empty)

        let missingCatalog = GraphCatalogProbe(error: .centerBookNotFound)
        let missingStore = GraphStore(catalog: missingCatalog)
        missingStore.load(centerBookID: firstID)
        await missingStore.waitForPendingWork()
        XCTAssertEqual(missingStore.state, .failed)
        XCTAssertEqual(missingStore.statusMessage, "中心书籍已不存在，请返回书库重新选择。")

        let failingCatalog = GraphCatalogProbe(error: .databaseUnavailable)
        let failingStore = GraphStore(catalog: failingCatalog)
        failingStore.load(centerBookID: firstID)
        await failingStore.waitForPendingWork()
        XCTAssertEqual(failingStore.state, .failed)
        XCTAssertTrue(failingStore.statusMessage?.contains("书库内容未被更改") == true)
    }

    func testHardCapsAndLimitMessageAreVisibleToStateLayer() async throws {
        let options = GraphBuildOptions(maximumNodes: 999, maximumEdges: 999)
        XCTAssertEqual(options.maximumNodes, GraphBuildOptions.hardMaximumNodes)
        XCTAssertEqual(options.maximumEdges, GraphBuildOptions.hardMaximumEdges)

        let catalog = GraphCatalogProbe(isLimited: true)
        let store = GraphStore(catalog: catalog)
        store.load(centerBookID: firstID)
        await store.waitForPendingWork()

        XCTAssertEqual(store.state, .content)
        XCTAssertTrue(store.scene?.snapshot.isLimited == true)
        XCTAssertTrue(store.statusMessage?.contains("稳定顺序截断") == true)
    }
}

private actor GraphCatalogProbe: LibraryCataloging {
    private var delayNanoseconds: UInt64
    private let perCenterDelay: [UUID: UInt64]
    private let ignoresCancellation: Bool
    private let returnsEmpty: Bool
    private let error: GraphBuildError?
    private let isLimited: Bool
    private var optionsLog: [GraphBuildOptions] = []

    init(
        delayNanoseconds: UInt64 = 0,
        perCenterDelay: [UUID: UInt64] = [:],
        ignoresCancellation: Bool = false,
        returnsEmpty: Bool = false,
        error: GraphBuildError? = nil,
        isLimited: Bool = false
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.perCenterDelay = perCenterDelay
        self.ignoresCancellation = ignoresCancellation
        self.returnsEmpty = returnsEmpty
        self.error = error
        self.isLimited = isLimited
    }

    func setDelay(_ value: UInt64) {
        delayNanoseconds = value
    }

    func recordedOptions() -> [GraphBuildOptions] {
        optionsLog
    }

    func localGraph(
        centerBookID: UUID,
        options: GraphBuildOptions
    ) throws -> GraphScene {
        optionsLog.append(options)
        let delay = perCenterDelay[centerBookID] ?? delayNanoseconds
        if delay > 0 {
            Thread.sleep(forTimeInterval: Double(delay) / 1_000_000_000)
            if !ignoresCancellation,
               withUnsafeCurrentTask(body: { $0?.isCancelled ?? false })
            {
                throw GraphBuildError.cancelled
            }
        }
        if let error { throw error }
        return Self.scene(
            centerID: centerBookID,
            empty: returnsEmpty,
            limited: isLimited
        )
    }

    func queryBooks(_ query: LibraryQuery) throws -> [Book] { [] }
    func createBook(from editor: BookEditorDraft) throws -> Book {
        throw BookRepositoryError.entityNotFound
    }
    func updateBook(_ book: Book, from editor: BookEditorDraft) throws -> Book {
        throw BookRepositoryError.entityNotFound
    }
    func deleteBook(_ book: Book) throws {
        throw BookRepositoryError.entityNotFound
    }

    private static func scene(
        centerID: UUID,
        empty: Bool,
        limited: Bool
    ) -> GraphScene {
        let neighborID = centerID.uuidString.hasSuffix("8101")
            ? UUID(uuidString: "00000000-0000-0000-0000-000000008102")!
            : UUID(uuidString: "00000000-0000-0000-0000-000000008101")!
        let center = GraphNode(
            id: centerID,
            title: "虚构中心",
            subtitle: "虚构作者",
            isCenter: true,
            isSelected: true,
            distance: 0
        )
        let neighbor = GraphNode(
            id: neighborID,
            title: "虚构邻书",
            subtitle: "虚构作者",
            isCenter: false,
            isSelected: false,
            distance: 1
        )
        let nodes = empty ? [center] : [center, neighbor]
        let edges = empty
            ? []
            : [
                GraphEdge(
                    id: GraphEdgeID(centerID, neighborID),
                    evidence: [.sameAuthor(author: "虚构作者")],
                    weight: 80
                )
            ]
        return GraphScene(
            snapshot: GraphSnapshot(
                centerBookID: centerID,
                nodes: nodes,
                edges: edges,
                nodeLimitReached: false,
                edgeLimitReached: false,
                sourceCandidatesWereTruncated: limited
            ),
            layout: GraphLayoutResult(
                positions: [
                    centerID: CGPoint(x: 300, y: 200),
                    neighborID: CGPoint(x: 480, y: 200)
                ],
                completedIterations: empty ? 0 : 10
            ),
            metrics: GraphSceneMetrics(
                querySeconds: 0.001,
                projectionSeconds: 0.001,
                layoutSeconds: 0.001
            )
        )
    }
}
