import CoreGraphics
import XCTest
@testable import BookAtlas

final class GraphProjectionTests: XCTestCase {
    private let centerID = UUID(uuidString: "00000000-0000-0000-0000-000000008001")!
    private let neighborID = UUID(uuidString: "00000000-0000-0000-0000-000000008002")!
    private let secondDegreeID = UUID(uuidString: "00000000-0000-0000-0000-000000008003")!
    private let timestamp = Date(timeIntervalSince1970: 1_735_689_600)

    func testRepositoryReturnsAllFiveConcreteRelationshipKindsOnOneEdge() throws {
        let repository = try BookRepository.inMemory()
        let center = try makeBook(repository, id: centerID, title: "《虚构潮线》", author: "林屿")
        let neighbor = try makeBook(repository, id: neighborID, title: "《虚构潮声》", author: "林屿")
        let tag = try repository.createTag(
            try Tag(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000008011")!,
                name: "虚构潮汐",
                createdAt: timestamp
            )
        )
        let collection = try repository.createCollection(
            try BookCollection(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000008012")!,
                name: "虚构港湾书单",
                createdAt: timestamp
            )
        )
        let source = try repository.createSource(
            try RecommendationSource(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000008013")!,
                name: "虚构纸页来源",
                createdAt: timestamp
            )
        )
        for book in [center, neighbor] {
            try repository.attach(tagID: tag.id, toBookID: book.id)
            try repository.add(bookID: book.id, toCollectionID: collection.id)
            try repository.attach(sourceID: source.id, toBookID: book.id)
        }
        _ = try repository.addManualRelation(
            try ManualBookRelation(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000008014")!,
                sourceBookID: center.id,
                targetBookID: neighbor.id,
                kind: .respondsTo,
                note: "固定虚构备注",
                createdAt: timestamp
            )
        )

        let batch = try repository.graphNeighbors(
            for: center.id,
            relationTypes: Set(GraphRelationType.allCases),
            limit: 20
        )

        XCTAssertFalse(batch.wasTruncated)
        XCTAssertEqual(batch.neighbors.map(\.book.id), [neighbor.id])
        let evidence = try XCTUnwrap(batch.neighbors.first?.evidence)
        XCTAssertEqual(Set(evidence.map(\.relationType)), Set(GraphRelationType.allCases))
        XCTAssertTrue(evidence.contains(.sameAuthor(author: "林屿")))
        XCTAssertTrue(evidence.contains(.sharedTag(id: tag.id, name: tag.name)))
        XCTAssertTrue(evidence.contains(.sameCollection(id: collection.id, name: collection.name)))
        XCTAssertTrue(evidence.contains(.sameSource(id: source.id, name: source.name)))
        XCTAssertTrue(
            evidence.contains {
                guard case let .manual(_, kind, _, sourceID, targetID, hasNote) = $0 else {
                    return false
                }
                return kind == .respondsTo
                    && sourceID == center.id
                    && targetID == neighbor.id
                    && hasNote
            }
        )
    }

    func testBuilderMergesEvidenceAndFiltersRelationshipsDeterministically() throws {
        let center = try book(id: centerID, title: "《虚构中心》", author: "甲")
        let neighbor = try book(id: neighborID, title: "《虚构邻书》", author: "甲")
        let tagID = UUID(uuidString: "00000000-0000-0000-0000-000000008021")!
        let allEvidence: [GraphRelationEvidence] = [
            .sameAuthor(author: "甲"),
            .sharedTag(id: tagID, name: "虚构标签"),
            .sharedTag(id: tagID, name: "虚构标签")
        ]
        let books = [center.id: center, neighbor.id: neighbor]
        let builder = LocalGraphBuilder()

        let all = try builder.build(
            centerBookID: center.id,
            options: GraphBuildOptions(relationTypes: [.sameAuthor, .sharedTag]),
            book: { books[$0] },
            neighbors: { id, _, _ in
                id == center.id
                    ? GraphNeighborBatch(
                        neighbors: [GraphNeighbor(book: neighbor, evidence: allEvidence)],
                        wasTruncated: false
                    )
                    : GraphNeighborBatch(neighbors: [], wasTruncated: false)
            }
        )
        let authorOnly = try builder.build(
            centerBookID: center.id,
            options: GraphBuildOptions(relationTypes: [.sameAuthor]),
            book: { books[$0] },
            neighbors: { id, allowed, _ in
                id == center.id
                    ? GraphNeighborBatch(
                        neighbors: [
                            GraphNeighbor(
                                book: neighbor,
                                evidence: allEvidence.filter { allowed.contains($0.relationType) }
                            )
                        ],
                        wasTruncated: false
                    )
                    : GraphNeighborBatch(neighbors: [], wasTruncated: false)
            }
        )

        XCTAssertEqual(all.nodes.count, 2)
        XCTAssertEqual(all.edges.count, 1)
        XCTAssertEqual(all.edges[0].evidence.count, 2)
        XCTAssertEqual(all.edges[0].weight, 100)
        XCTAssertEqual(authorOnly.edges[0].evidence, [.sameAuthor(author: "甲")])
        XCTAssertEqual(authorOnly.edges[0].weight, 80)
    }

    func testDirectAndSecondDegreeTraversalHaveExpectedDistances() throws {
        let center = try book(id: centerID, title: "中心", author: "甲")
        let direct = try book(id: neighborID, title: "一层", author: "乙")
        let second = try book(id: secondDegreeID, title: "二层", author: "丙")
        let books = [center.id: center, direct.id: direct, second.id: second]
        let evidence = GraphRelationEvidence.sameAuthor(author: "虚构作者")
        let lookup: LocalGraphBuilder.NeighborLookup = { id, _, _ in
            switch id {
            case center.id:
                GraphNeighborBatch(
                    neighbors: [GraphNeighbor(book: direct, evidence: [evidence])],
                    wasTruncated: false
                )
            case direct.id:
                GraphNeighborBatch(
                    neighbors: [GraphNeighbor(book: second, evidence: [evidence])],
                    wasTruncated: false
                )
            default:
                GraphNeighborBatch(neighbors: [], wasTruncated: false)
            }
        }
        let builder = LocalGraphBuilder()

        let oneLayer = try builder.build(
            centerBookID: center.id,
            options: GraphBuildOptions(depth: .direct),
            book: { books[$0] },
            neighbors: lookup
        )
        let twoLayers = try builder.build(
            centerBookID: center.id,
            options: GraphBuildOptions(depth: .secondDegree),
            book: { books[$0] },
            neighbors: lookup
        )

        XCTAssertEqual(Set(oneLayer.nodes.map(\.id)), [center.id, direct.id])
        XCTAssertEqual(Set(twoLayers.nodes.map(\.id)), [center.id, direct.id, second.id])
        XCTAssertEqual(twoLayers.nodes.first { $0.id == second.id }?.distance, 2)
    }

    func testLimitsAreExplicitAndDoNotCreateOrphanNodes() throws {
        let center = try book(id: centerID, title: "中心", author: "甲")
        let first = try book(id: neighborID, title: "一", author: "甲")
        let second = try book(id: secondDegreeID, title: "二", author: "甲")
        let books = [center.id: center, first.id: first, second.id: second]
        let batch = GraphNeighborBatch(
            neighbors: [
                GraphNeighbor(book: first, evidence: [.sameAuthor(author: "甲")]),
                GraphNeighbor(book: second, evidence: [.sameAuthor(author: "甲")])
            ],
            wasTruncated: true
        )

        let nodeLimited = try LocalGraphBuilder().build(
            centerBookID: center.id,
            options: GraphBuildOptions(maximumNodes: 2, maximumEdges: 10),
            book: { books[$0] },
            neighbors: { id, _, _ in
                id == center.id ? batch : GraphNeighborBatch(neighbors: [], wasTruncated: false)
            }
        )
        let edgeLimited = try LocalGraphBuilder().build(
            centerBookID: center.id,
            options: GraphBuildOptions(maximumNodes: 3, maximumEdges: 0),
            book: { books[$0] },
            neighbors: { id, _, _ in
                id == center.id ? batch : GraphNeighborBatch(neighbors: [], wasTruncated: false)
            }
        )

        XCTAssertEqual(nodeLimited.nodes.count, 2)
        XCTAssertEqual(nodeLimited.edges.count, 1)
        XCTAssertTrue(nodeLimited.nodeLimitReached)
        XCTAssertTrue(nodeLimited.sourceCandidatesWereTruncated)
        XCTAssertEqual(edgeLimited.nodes.map(\.id), [center.id])
        XCTAssertTrue(edgeLimited.edgeLimitReached)
    }

    func testRepositoryLimitUsesStableRankingAndReportsTruncation() throws {
        let repository = try BookRepository.inMemory()
        let center = try makeBook(repository, id: centerID, title: "中心", author: "共同虚构作者")
        for index in 2 ... 302 {
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 8_000 + index))!
            _ = try makeBook(repository, id: id, title: "虚构书 \(index)", author: "共同虚构作者")
        }

        let first = try repository.graphNeighbors(
            for: center.id,
            relationTypes: [.sameAuthor],
            limit: 250
        )
        let second = try repository.graphNeighbors(
            for: center.id,
            relationTypes: [.sameAuthor],
            limit: 250
        )

        XCTAssertEqual(first.neighbors.count, 250)
        XCTAssertTrue(first.wasTruncated)
        XCTAssertEqual(first, second)
        XCTAssertEqual(
            first.neighbors.map(\.book.id.uuidString),
            first.neighbors.map(\.book.id.uuidString).sorted()
        )
    }

    func testMergedBookRetainsProjectedRelationshipAndRemovedIdentityDisappears() throws {
        let repository = try BookRepository.inMemory()
        let target = try makeBook(repository, id: centerID, title: "目标", author: "甲")
        let source = try makeBook(repository, id: neighborID, title: "来源", author: "乙")
        let related = try makeBook(repository, id: secondDegreeID, title: "相关书", author: "丙")
        let tag = try repository.createTag(try Tag(name: "虚构迁移标签", createdAt: timestamp))
        try repository.attach(tagID: tag.id, toBookID: source.id)
        try repository.attach(tagID: tag.id, toBookID: related.id)

        let preview = try repository.mergePreview(targetID: target.id, sourceID: source.id)
        _ = try repository.mergeBooks(
            targetID: target.id,
            sourceID: source.id,
            selections: preview.defaultSelections,
            at: timestamp.addingTimeInterval(5)
        )

        let batch = try repository.graphNeighbors(
            for: target.id,
            relationTypes: [.sharedTag],
            limit: 20
        )
        XCTAssertEqual(batch.neighbors.map(\.book.id), [related.id])
        XCTAssertNil(try repository.book(id: source.id))
        XCTAssertThrowsError(
            try repository.graphNeighbors(
                for: source.id,
                relationTypes: Set(GraphRelationType.allCases),
                limit: 20
            )
        ) {
            XCTAssertEqual($0 as? GraphBuildError, .centerBookNotFound)
        }
    }

    func testKeptDuplicateVersionsRemainSeparateGraphNodes() throws {
        let repository = try BookRepository.inMemory()
        let first = try makeBook(repository, id: centerID, title: "同名虚构书", author: "甲")
        let second = try makeBook(repository, id: neighborID, title: "同名虚构书", author: "甲")
        try repository.ignoreDuplicatePair(
            first.id,
            second.id,
            disposition: .separateEdition,
            at: timestamp
        )

        let snapshot = try LocalGraphBuilder().build(
            centerBookID: first.id,
            options: GraphBuildOptions(relationTypes: [.sameAuthor]),
            book: { try repository.book(id: $0) },
            neighbors: {
                try repository.graphNeighbors(for: $0, relationTypes: $1, limit: $2)
            }
        )

        XCTAssertEqual(Set(snapshot.nodes.map(\.id)), [first.id, second.id])
        XCTAssertNotNil(
            try repository.ignoredDuplicatePair(between: first.id, and: second.id)
        )
    }

    func testLayoutIsDeterministicBoundedAndKeepsCenterFixed() throws {
        let snapshot = try sampleSnapshot()
        let options = GraphLayoutOptions(
            size: CGSize(width: 900, height: 600),
            maximumIterations: 30
        )
        let layout = DeterministicGraphLayout()

        let first = try layout.layout(snapshot: snapshot, options: options)
        let second = try layout.layout(snapshot: snapshot, options: options)

        XCTAssertEqual(first, second)
        XCTAssertLessThanOrEqual(first.completedIterations, 30)
        XCTAssertEqual(first.positions[centerID], CGPoint(x: 450, y: 300))
        XCTAssertEqual(first.positions.count, snapshot.nodes.count)
    }

    func testLayoutHandlesEmptySingleNodeAndCancellation() throws {
        let empty = GraphSnapshot(
            centerBookID: centerID,
            nodes: [],
            edges: [],
            nodeLimitReached: false,
            edgeLimitReached: false,
            sourceCandidatesWereTruncated: false
        )
        let single = GraphSnapshot(
            centerBookID: centerID,
            nodes: [
                GraphNode(
                    id: centerID,
                    title: "中心",
                    subtitle: nil,
                    isCenter: true,
                    isSelected: true,
                    distance: 0
                )
            ],
            edges: [],
            nodeLimitReached: false,
            edgeLimitReached: false,
            sourceCandidatesWereTruncated: false
        )

        XCTAssertEqual(try DeterministicGraphLayout().layout(snapshot: empty).positions, [:])
        XCTAssertEqual(
            try DeterministicGraphLayout().layout(snapshot: single).completedIterations,
            0
        )
        XCTAssertThrowsError(
            try DeterministicGraphLayout().layout(
                snapshot: try sampleSnapshot(),
                cancellation: GraphBuildCancellation(isCancelled: { true })
            )
        ) {
            XCTAssertEqual($0 as? GraphBuildError, .cancelled)
        }
    }

    func testBuilderCancellationAndMissingCenterAreExplicit() throws {
        let center = try book(id: centerID, title: "中心", author: "甲")
        XCTAssertThrowsError(
            try LocalGraphBuilder().build(
                centerBookID: center.id,
                options: GraphBuildOptions(),
                cancellation: GraphBuildCancellation(isCancelled: { true }),
                book: { _ in center },
                neighbors: { _, _, _ in
                    GraphNeighborBatch(neighbors: [], wasTruncated: false)
                }
            )
        ) {
            XCTAssertEqual($0 as? GraphBuildError, .cancelled)
        }
        XCTAssertThrowsError(
            try LocalGraphBuilder().build(
                centerBookID: center.id,
                options: GraphBuildOptions(),
                book: { _ in nil },
                neighbors: { _, _, _ in
                    GraphNeighborBatch(neighbors: [], wasTruncated: false)
                }
            )
        ) {
            XCTAssertEqual($0 as? GraphBuildError, .centerBookNotFound)
        }
    }

    private func makeBook(
        _ repository: BookRepository,
        id: UUID,
        title: String,
        author: String
    ) throws -> Book {
        try repository.create(
            BookDraft(title: title, author: author),
            id: id,
            at: timestamp
        )
    }

    private func book(id: UUID, title: String, author: String) throws -> Book {
        try Book(
            id: id,
            draft: BookDraft(title: title, author: author),
            createdAt: timestamp
        )
    }

    private func sampleSnapshot() throws -> GraphSnapshot {
        let center = try book(id: centerID, title: "中心", author: "甲")
        let neighbor = try book(id: neighborID, title: "邻书", author: "乙")
        let second = try book(id: secondDegreeID, title: "二层", author: "丙")
        let nodes = [
            GraphNode(
                id: center.id,
                title: center.title,
                subtitle: center.author,
                isCenter: true,
                isSelected: true,
                distance: 0
            ),
            GraphNode(
                id: neighbor.id,
                title: neighbor.title,
                subtitle: neighbor.author,
                isCenter: false,
                isSelected: false,
                distance: 1
            ),
            GraphNode(
                id: second.id,
                title: second.title,
                subtitle: second.author,
                isCenter: false,
                isSelected: false,
                distance: 2
            )
        ]
        return GraphSnapshot(
            centerBookID: center.id,
            nodes: nodes,
            edges: [
                GraphEdge(
                    id: GraphEdgeID(center.id, neighbor.id),
                    evidence: [.sameAuthor(author: "甲")],
                    weight: 80
                ),
                GraphEdge(
                    id: GraphEdgeID(neighbor.id, second.id),
                    evidence: [.sharedTag(id: centerID, name: "虚构标签")],
                    weight: 20
                )
            ],
            nodeLimitReached: false,
            edgeLimitReached: false,
            sourceCandidatesWereTruncated: false
        )
    }
}
