import CoreGraphics
import XCTest
@testable import BookAtlas

private let graphStoreFirstID =
    UUID(uuidString: "00000000-0000-0000-0000-000000008101")!
private let graphStoreSecondID =
    UUID(uuidString: "00000000-0000-0000-0000-000000008102")!

@MainActor
final class GraphStoreTests: XCTestCase {
    private let firstID = graphStoreFirstID
    private let secondID = graphStoreSecondID

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
        XCTAssertEqual(missingStore.state, .missingCenter)
        XCTAssertNil(missingStore.scene)
        XCTAssertNil(missingStore.centerBookID)
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

    func testCanvasPanUsesGestureStartWithCumulativeTranslations() {
        var interaction = GraphCanvasInteractionState()
        interaction.beginDrag(hitNodeID: nil)

        for expected in [CGFloat(10), 20, 30] {
            let update = interaction.updateDrag(
                cumulativeTranslation: CGSize(width: expected, height: expected / 2),
                location: .zero
            )
            XCTAssertEqual(
                update,
                .panned(CGSize(width: expected, height: expected / 2))
            )
            XCTAssertEqual(interaction.viewport.translation.width, expected)
        }
    }

    func testCanvasDragModeIsFixedForOneGesture() {
        var pan = GraphCanvasInteractionState()
        pan.beginDrag(hitNodeID: nil)
        pan.beginDrag(hitNodeID: firstID)
        XCTAssertEqual(pan.dragState, .panning(initialTranslation: .zero))

        var nodeDrag = GraphCanvasInteractionState()
        nodeDrag.beginDrag(hitNodeID: firstID)
        nodeDrag.beginDrag(hitNodeID: nil)
        XCTAssertEqual(nodeDrag.dragState, .draggingNode(firstID))
    }

    func testCanvasNodeDragInvertsScaleAndTranslation() {
        var interaction = GraphCanvasInteractionState(
            viewport: GraphViewportState(
                scale: 2,
                translation: CGSize(width: 100, height: 50)
            )
        )
        interaction.beginDrag(hitNodeID: firstID)

        XCTAssertEqual(
            interaction.updateDrag(
                cumulativeTranslation: CGSize(width: 50, height: 50),
                location: CGPoint(x: 300, y: 250)
            ),
            .movedNode(firstID, CGPoint(x: 100, y: 100))
        )
        XCTAssertEqual(
            interaction.viewport,
            GraphViewportState(
                scale: 2,
                translation: CGSize(width: 100, height: 50)
            )
        )
    }

    func testCanvasGestureEndCapturesANewStartForNextPan() {
        var interaction = GraphCanvasInteractionState()
        interaction.beginDrag(hitNodeID: nil)
        _ = interaction.updateDrag(
            cumulativeTranslation: CGSize(width: 30, height: 15),
            location: .zero
        )
        interaction.endDrag()
        interaction.beginDrag(hitNodeID: nil)
        _ = interaction.updateDrag(
            cumulativeTranslation: CGSize(width: 10, height: -5),
            location: .zero
        )

        XCTAssertEqual(
            interaction.viewport.translation,
            CGSize(width: 40, height: 10)
        )
    }

    func testCanvasResetRestoresViewportAndClearsGesture() {
        var interaction = GraphCanvasInteractionState(
            viewport: GraphViewportState(
                scale: 1.8,
                translation: CGSize(width: 90, height: -30)
            )
        )
        interaction.beginDrag(hitNodeID: firstID)

        interaction.reset(
            to: GraphViewportState(
                scale: 1,
                translation: CGSize(width: 400, height: 260)
            )
        )

        XCTAssertEqual(interaction.dragState, .idle)
        XCTAssertEqual(interaction.viewport.scale, 1)
        XCTAssertEqual(
            interaction.viewport.translation,
            CGSize(width: 400, height: 260)
        )
        XCTAssertNil(
            interaction.updateDrag(
                cumulativeTranslation: CGSize(width: 20, height: 20),
                location: CGPoint(x: 20, y: 20)
            )
        )
    }
}

extension GraphStoreTests {
    func testReentryAfterBookIdentityUpdateReloadsTitleAndAuthor() async throws {
        let (service, center) = try await Task.detached {
            let repository = try BookRepository.inMemory()
            let center = try makeGraphTestBook(
                repository,
                id: graphStoreFirstID,
                title: "《旧虚构中心》",
                author: "旧虚构作者"
            )
            _ = try makeGraphTestBook(
                repository,
                id: graphStoreSecondID,
                title: "《旧虚构邻书》",
                author: "旧虚构作者"
            )
            return (LibraryCatalogService(repository: repository), center)
        }.value
        let store = GraphStore(catalog: service)

        store.enter(centerBookID: center.id)
        await settle(store)
        XCTAssertEqual(store.scene?.snapshot.nodes.first { $0.id == center.id }?.title, "《旧虚构中心》")
        store.leave()

        _ = try await service.updateBook(
            center,
            from: BookEditorDraft(title: "《新虚构中心》", author: "新虚构作者")
        )
        store.enter(centerBookID: nil)
        await settle(store)

        let currentRevision = await service.graphContentRevision()
        XCTAssertEqual(store.loadedRevision, currentRevision)
        XCTAssertEqual(store.scene?.snapshot.nodes.first { $0.id == center.id }?.title, "《新虚构中心》")
        XCTAssertEqual(store.scene?.snapshot.nodes.first { $0.id == center.id }?.subtitle, "新虚构作者")
        XCTAssertFalse(store.scene?.snapshot.nodes.contains { $0.title == "《旧虚构邻书》" } == true)
    }

    func testAssociationAndManualRelationChangesRefreshConcreteEvidence() async throws {
        let (service, center, neighbor) = try await Task.detached {
            let repository = try BookRepository.inMemory()
            let center = try makeGraphTestBook(
                repository,
                id: graphStoreFirstID,
                title: "《关联中心》",
                author: "虚构甲"
            )
            let neighbor = try makeGraphTestBook(
                repository,
                id: graphStoreSecondID,
                title: "《关联邻书》",
                author: "虚构乙"
            )
            return (LibraryCatalogService(repository: repository), center, neighbor)
        }.value
        let store = GraphStore(catalog: service)
        store.enter(centerBookID: center.id)
        await settle(store)
        XCTAssertTrue(store.scene?.snapshot.edges.isEmpty == true)
        store.leave()

        let tag = try await service.createTag(name: "虚构刷新标签")
        let collection = try await service.createCollection(
            name: "虚构刷新书单",
            description: nil
        )
        let source = try await service.createSource(name: "虚构刷新来源", details: nil)
        for book in [center, neighbor] {
            try await service.setAssociation(.tag(tag.id), included: true, bookID: book.id)
            try await service.setAssociation(
                .collection(collection.id),
                included: true,
                bookID: book.id
            )
            try await service.setAssociation(.source(source.id), included: true, bookID: book.id)
        }
        let relation = try ManualBookRelation(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000008103")!,
            sourceBookID: center.id,
            targetBookID: neighbor.id,
            kind: .companion,
            note: "固定虚构备注",
            createdAt: FictionalLibraryFixtures.timestamp
        )
        _ = try await service.addManualRelation(relation)

        store.enter(centerBookID: nil)
        await settle(store)
        let edge = try XCTUnwrap(store.scene?.snapshot.edges.first)
        XCTAssertEqual(
            edge.relationTypes,
            [.sharedTag, .sameCollection, .sameSource, .manual]
        )
        store.leave()

        let renamedTag = try await service.renameTag(tag, name: "虚构刷新标签（新）")
        let renamedCollection = try await service.renameCollection(
            collection,
            name: "虚构刷新书单（新）",
            description: nil
        )
        let renamedSource = try await service.renameSource(
            source,
            name: "虚构刷新来源（新）",
            details: nil
        )
        store.enter(centerBookID: nil)
        await settle(store)
        let renamedEvidence = try XCTUnwrap(store.scene?.snapshot.edges.first?.evidence)
        XCTAssertTrue(
            renamedEvidence.contains(.sharedTag(id: renamedTag.id, name: renamedTag.name))
        )
        XCTAssertTrue(
            renamedEvidence.contains(
                .sameCollection(id: renamedCollection.id, name: renamedCollection.name)
            )
        )
        XCTAssertTrue(
            renamedEvidence.contains(.sameSource(id: renamedSource.id, name: renamedSource.name))
        )
        store.leave()

        try await service.setAssociation(.tag(tag.id), included: false, bookID: neighbor.id)
        try await service.setAssociation(
            .collection(collection.id),
            included: false,
            bookID: neighbor.id
        )
        try await service.setAssociation(.source(source.id), included: false, bookID: neighbor.id)
        try await service.deleteManualRelation(relation)
        store.enter(centerBookID: nil)
        await settle(store)

        XCTAssertTrue(store.scene?.snapshot.edges.isEmpty == true)
        XCTAssertFalse(store.scene?.snapshot.nodes.contains { $0.id == neighbor.id } == true)
    }

    func testDeletedNeighborDoesNotSurviveReentry() async throws {
        let (service, center, neighbor) = try await Task.detached {
            let repository = try BookRepository.inMemory()
            let center = try makeGraphTestBook(
                repository,
                id: graphStoreFirstID,
                title: "《删除中心》",
                author: "共同虚构作者"
            )
            let neighbor = try makeGraphTestBook(
                repository,
                id: graphStoreSecondID,
                title: "《待删邻书》",
                author: "共同虚构作者"
            )
            return (LibraryCatalogService(repository: repository), center, neighbor)
        }.value
        let store = GraphStore(catalog: service)
        store.enter(centerBookID: center.id)
        await settle(store)
        XCTAssertTrue(store.scene?.snapshot.nodes.contains { $0.id == neighbor.id } == true)
        store.leave()

        try await service.deleteBook(neighbor)
        store.enter(centerBookID: nil)
        await settle(store)

        XCTAssertFalse(store.scene?.snapshot.nodes.contains { $0.id == neighbor.id } == true)
        XCTAssertFalse(
            store.scene?.snapshot.edges.contains {
                $0.id.firstBookID == neighbor.id || $0.id.secondBookID == neighbor.id
            } == true
        )
    }

    func testDeletedCenterClearsOldSceneAndEntersExplicitMissingState() async throws {
        let (service, center) = try await Task.detached {
            let repository = try BookRepository.inMemory()
            let center = try makeGraphTestBook(
                repository,
                id: graphStoreFirstID,
                title: "《将删除中心》",
                author: "共同虚构作者"
            )
            _ = try makeGraphTestBook(
                repository,
                id: graphStoreSecondID,
                title: "《旧邻书》",
                author: "共同虚构作者"
            )
            return (LibraryCatalogService(repository: repository), center)
        }.value
        let store = GraphStore(catalog: service)
        store.enter(centerBookID: center.id)
        await settle(store)
        XCTAssertNotNil(store.scene)
        store.leave()

        try await service.deleteBook(center)
        store.enter(centerBookID: nil)
        await settle(store)

        XCTAssertEqual(store.state, .missingCenter)
        XCTAssertNil(store.centerBookID)
        XCTAssertNil(store.scene)
        XCTAssertEqual(store.statusMessage, "中心书籍已不存在，请返回书库重新选择。")
    }

    func testMergeRemovesSourceIdentityAndRefreshesRetainedRelationships() async throws {
        let relatedID = UUID(uuidString: "00000000-0000-0000-0000-000000008104")!
        let (service, target, source, related, tag) = try await Task.detached {
            let repository = try BookRepository.inMemory()
            let target = try makeGraphTestBook(
                repository,
                id: graphStoreFirstID,
                title: "《保留书》",
                author: "虚构甲"
            )
            let source = try makeGraphTestBook(
                repository,
                id: graphStoreSecondID,
                title: "《合并来源》",
                author: "虚构乙"
            )
            let related = try makeGraphTestBook(
                repository,
                id: relatedID,
                title: "《迁移关系邻书》",
                author: "虚构丙"
            )
            let tag = try repository.createTag(
                try Tag(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000008105")!,
                    name: "虚构迁移标签",
                    createdAt: FictionalLibraryFixtures.timestamp
                )
            )
            try repository.attach(tagID: tag.id, toBookID: source.id)
            try repository.attach(tagID: tag.id, toBookID: related.id)
            return (
                LibraryCatalogService(repository: repository),
                target,
                source,
                related,
                tag
            )
        }.value
        let targetStore = GraphStore(catalog: service)
        let removedCenterStore = GraphStore(catalog: service)
        targetStore.enter(centerBookID: target.id)
        removedCenterStore.enter(centerBookID: source.id)
        await settle(targetStore)
        await settle(removedCenterStore)
        targetStore.leave()
        removedCenterStore.leave()

        let preview = try await service.mergePreview(targetID: target.id, sourceID: source.id)
        _ = try await service.mergeBooks(
            targetID: target.id,
            sourceID: source.id,
            selections: preview.defaultSelections
        )
        targetStore.enter(centerBookID: nil)
        removedCenterStore.enter(centerBookID: nil)
        await settle(targetStore)
        await settle(removedCenterStore)

        XCTAssertFalse(targetStore.scene?.snapshot.nodes.contains { $0.id == source.id } == true)
        XCTAssertTrue(targetStore.scene?.snapshot.nodes.contains { $0.id == related.id } == true)
        XCTAssertTrue(
            targetStore.scene?.snapshot.edges.first?.evidence.contains(
                .sharedTag(id: tag.id, name: tag.name)
            ) == true
        )
        XCTAssertEqual(removedCenterStore.state, .missingCenter)
        XCTAssertNil(removedCenterStore.scene)
        XCTAssertNil(removedCenterStore.centerBookID)
    }

    func testCSVImportInvalidatesGraphAndExposesImportedRelationship() async throws {
        let directory = try temporaryDirectory(named: "Import")
        defer { try? FileManager.default.removeItem(at: directory) }
        let (service, center) = try await Task.detached {
            let repository = try BookRepository.inMemory()
            let center = try makeGraphTestBook(
                repository,
                id: graphStoreFirstID,
                title: "《导入中心》",
                author: "虚构甲"
            )
            let tag = try repository.createTag(
                try Tag(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000008106")!,
                    name: "虚构导入标签",
                    createdAt: FictionalLibraryFixtures.timestamp
                )
            )
            try repository.attach(tagID: tag.id, toBookID: center.id)
            return (LibraryCatalogService(repository: repository), center)
        }.value
        let store = GraphStore(catalog: service)
        store.enter(centerBookID: center.id)
        await settle(store)
        store.leave()

        let csvURL = directory.appendingPathComponent("fictional.csv")
        try Data(
            """
            format_version,title,author,tags
            bookatlas-csv/1,《导入关系邻书》,虚构乙,虚构导入标签
            """.utf8
        ).write(to: csvURL)
        let preview = try await service.prepareImport(from: csvURL, mapping: nil)
        let result = try await service.executeImport(preview)
        XCTAssertEqual(result.imported, 1)

        store.enter(centerBookID: nil)
        await settle(store)

        XCTAssertTrue(
            store.scene?.snapshot.nodes.contains { $0.title == "《导入关系邻书》" } == true
        )
        XCTAssertTrue(
            store.scene?.snapshot.edges.first?.relationTypes.contains(.sharedTag) == true
        )
    }

    func testRestoreClearsPreRestoreGraphWhenCenterNoLongerExists() async throws {
        let directory = try temporaryDirectory(named: "Restore")
        defer { try? FileManager.default.removeItem(at: directory) }
        try await verifyRestoreClearsPreRestoreGraph(in: directory)
    }

    private func verifyRestoreClearsPreRestoreGraph(in directory: URL) async throws {
        let liveURL = directory.appendingPathComponent("live.sqlite")
        let backupURL = directory.appendingPathComponent("source.bookatlasbackup")
        let (service, center) = try await Task.detached {
            let liveRepository = try BookRepository(databaseURL: liveURL)
            let center = try makeGraphTestBook(
                liveRepository,
                id: graphStoreFirstID,
                title: "《恢复前中心》",
                author: "恢复前虚构作者"
            )
            _ = try makeGraphTestBook(
                liveRepository,
                id: graphStoreSecondID,
                title: "《恢复前邻书》",
                author: "恢复前虚构作者"
            )
            let sourceURL = directory.appendingPathComponent("source.sqlite")
            let sourceRepository = try BookRepository(databaseURL: sourceURL)
            _ = try makeGraphTestBook(
                sourceRepository,
                id: UUID(uuidString: "00000000-0000-0000-0000-000000008107")!,
                title: "《恢复后唯一书》",
                author: "恢复后虚构作者"
            )
            _ = try LibraryBackupCoordinator(applicationVersion: "8-test").backup(
                repository: sourceRepository,
                to: backupURL
            )
            let service = LibraryCatalogService(
                repository: liveRepository,
                databaseURL: liveURL,
                recoveryDirectory: directory.appendingPathComponent("recovery")
            )
            return (service, center)
        }.value
        let store = GraphStore(catalog: service)
        store.enter(centerBookID: center.id)
        await settle(store)
        XCTAssertTrue(store.scene?.snapshot.nodes.contains { $0.id == secondID } == true)
        store.leave()

        _ = try await service.restoreBackup(
            at: backupURL,
            control: RestoreOperationControl(),
            progress: { _ in }
        )

        store.enter(centerBookID: nil)
        await settle(store)
        XCTAssertEqual(store.state, .missingCenter)
        XCTAssertNil(store.scene)
        XCTAssertNil(store.centerBookID)
        let restoredTitles = try await service.queryBooks(LibraryQuery()).map(\.title)
        XCTAssertEqual(
            restoredTitles,
            ["《恢复后唯一书》"]
        )
        try await service.close()
    }

    func testUnchangedRevisionReentryPreservesLayout() async throws {
        let (service, center, neighbor) = try await Task.detached {
            let repository = try BookRepository.inMemory()
            let center = try makeGraphTestBook(
                repository,
                id: graphStoreFirstID,
                title: "《布局中心》",
                author: "共同虚构作者"
            )
            let neighbor = try makeGraphTestBook(
                repository,
                id: graphStoreSecondID,
                title: "《布局邻书》",
                author: "共同虚构作者"
            )
            return (LibraryCatalogService(repository: repository), center, neighbor)
        }.value
        let store = GraphStore(catalog: service)
        store.enter(centerBookID: center.id)
        await settle(store)
        let moved = CGPoint(x: 731, y: 419)
        store.moveNode(neighbor.id, to: moved)
        let revision = store.loadedRevision

        store.leave()
        store.enter(centerBookID: nil)
        await settle(store)

        XCTAssertEqual(store.loadedRevision, revision)
        XCTAssertEqual(store.scene?.layout.positions[neighbor.id], moved)
    }

    func testSlowOldRevisionCannotPublishAfterNewRevision() async throws {
        let source = GraphRevisionRaceSource(
            centerID: firstID,
            initialTitle: "《旧 revision》"
        )
        let store = GraphStore(catalog: GraphRevisionRaceCatalog(source: source))
        store.enter(centerBookID: firstID)
        for _ in 0 ..< 1_000 where !source.firstBuildHasStarted() {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(source.firstBuildHasStarted())

        source.advance(title: "《新 revision》")
        for _ in 0 ..< 1_000 where source.completedBuildCount() < 2 {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        await store.waitForPendingWork()

        XCTAssertGreaterThanOrEqual(source.completedBuildCount(), 2)
        XCTAssertEqual(store.loadedRevision, GraphContentRevision(rawValue: 1))
        XCTAssertEqual(store.scene?.snapshot.nodes.first?.title, "《新 revision》")
        XCTAssertFalse(store.scene?.snapshot.nodes.contains { $0.title == "《旧 revision》" } == true)
    }

    @MainActor
    private func settle(_ store: GraphStore) async {
        for _ in 0 ..< 4 {
            await Task.yield()
            await store.waitForPendingWork()
        }
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookAtlas-Graph\(name)Tests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private func makeGraphTestBook(
    _ repository: BookRepository,
    id: UUID,
    title: String,
    author: String
) throws -> Book {
    try repository.create(
        BookDraft(title: title, author: author),
        id: id,
        at: FictionalLibraryFixtures.timestamp
    )
}

private final class GraphRevisionRaceSource: @unchecked Sendable {
    private let lock = NSLock()
    private let centerID: UUID
    private var revision = GraphContentRevision.initial
    private var title: String
    private var buildCount = 0
    private var completedBuilds = 0
    private var continuations: [UUID: AsyncStream<GraphContentRevision>.Continuation] = [:]

    init(centerID: UUID, initialTitle: String) {
        self.centerID = centerID
        title = initialTitle
    }

    func currentRevision() -> GraphContentRevision {
        lock.withLock { revision }
    }

    func firstBuildHasStarted() -> Bool {
        lock.withLock { buildCount > 0 }
    }

    func completedBuildCount() -> Int {
        lock.withLock { completedBuilds }
    }

    func stream() -> AsyncStream<GraphContentRevision> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<GraphContentRevision>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        lock.withLock {
            continuations[id] = continuation
            continuation.yield(revision)
        }
        continuation.onTermination = { [weak self] _ in
            _ = self?.lock.withLock {
                self?.continuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    func advance(title: String) {
        let update = lock.withLock { () -> (GraphContentRevision, [AsyncStream<GraphContentRevision>.Continuation]) in
            self.title = title
            revision = revision.advanced()
            return (revision, Array(continuations.values))
        }
        for continuation in update.1 {
            continuation.yield(update.0)
        }
    }

    func buildScene() -> GraphScene {
        let snapshot = lock.withLock { () -> (GraphContentRevision, String, Bool) in
            buildCount += 1
            return (revision, title, buildCount == 1)
        }
        if snapshot.2 {
            Thread.sleep(forTimeInterval: 0.18)
        }
        lock.withLock {
            completedBuilds += 1
        }
        let node = GraphNode(
            id: centerID,
            title: snapshot.1,
            subtitle: "虚构 revision 作者",
            isCenter: true,
            isSelected: true,
            distance: 0
        )
        return GraphScene(
            snapshot: GraphSnapshot(
                centerBookID: centerID,
                nodes: [node],
                edges: [],
                nodeLimitReached: false,
                edgeLimitReached: false,
                sourceCandidatesWereTruncated: false
            ),
            layout: GraphLayoutResult(
                positions: [centerID: CGPoint(x: 300, y: 200)],
                completedIterations: 0
            ),
            metrics: GraphSceneMetrics(
                querySeconds: 0,
                projectionSeconds: 0,
                layoutSeconds: 0
            ),
            contentRevision: snapshot.0
        )
    }
}

private actor GraphRevisionRaceCatalog: LibraryCataloging {
    private let source: GraphRevisionRaceSource

    init(source: GraphRevisionRaceSource) {
        self.source = source
    }

    func graphContentRevision() -> GraphContentRevision {
        source.currentRevision()
    }

    func graphContentRevisions() -> AsyncStream<GraphContentRevision> {
        source.stream()
    }

    func localGraph(
        centerBookID: UUID,
        options: GraphBuildOptions
    ) throws -> GraphScene {
        source.buildScene()
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
            ),
            contentRevision: .initial
        )
    }
}
