import Foundation

extension BookRepository {
    func graphNeighbors(
        for bookID: UUID,
        relationTypes: Set<GraphRelationType>,
        limit: Int
    ) throws -> GraphNeighborBatch {
        guard limit > 0 else {
            return GraphNeighborBatch(neighbors: [], wasTruncated: true)
        }
        guard let center = try book(id: bookID) else {
            throw GraphBuildError.centerBookNotFound
        }

        var evidenceByBookID: [UUID: Set<GraphRelationEvidence>] = [:]
        var wasTruncated = false

        if relationTypes.contains(.sameAuthor) {
            let result = try sameAuthorEvidence(center: center, limit: limit)
            wasTruncated = wasTruncated || result.wasTruncated
            merge(result.values, into: &evidenceByBookID)
        }
        if relationTypes.contains(.sharedTag) {
            let result = try sharedAssociationEvidence(
                bookID: bookID,
                joinTable: "book_tags",
                associationColumn: "tag_id",
                catalogTable: "tags",
                relation: { id, name in .sharedTag(id: id, name: name) },
                limit: limit
            )
            wasTruncated = wasTruncated || result.wasTruncated
            merge(result.values, into: &evidenceByBookID)
        }
        if relationTypes.contains(.sameCollection) {
            let result = try sharedAssociationEvidence(
                bookID: bookID,
                joinTable: "book_collections_books",
                associationColumn: "collection_id",
                catalogTable: "book_collections",
                relation: { id, name in .sameCollection(id: id, name: name) },
                limit: limit
            )
            wasTruncated = wasTruncated || result.wasTruncated
            merge(result.values, into: &evidenceByBookID)
        }
        if relationTypes.contains(.sameSource) {
            let result = try sharedAssociationEvidence(
                bookID: bookID,
                joinTable: "book_sources",
                associationColumn: "source_id",
                catalogTable: "recommendation_sources",
                relation: { id, name in .sameSource(id: id, name: name) },
                limit: limit
            )
            wasTruncated = wasTruncated || result.wasTruncated
            merge(result.values, into: &evidenceByBookID)
        }
        if relationTypes.contains(.manual) {
            let result = try manualRelationEvidence(bookID: bookID, limit: limit)
            wasTruncated = wasTruncated || result.wasTruncated
            merge(result.values, into: &evidenceByBookID)
        }

        evidenceByBookID.removeValue(forKey: bookID)
        let ranked = evidenceByBookID.map { bookID, evidence in
            GraphRankedNeighbor(
                bookID: bookID,
                evidence: evidence.sorted { $0.sortKey < $1.sortKey },
                weight: GraphWeightModel.weight(for: Array(evidence))
            )
        }.sorted {
            if $0.weight != $1.weight { return $0.weight > $1.weight }
            return $0.bookID.uuidString < $1.bookID.uuidString
        }
        if ranked.count > limit {
            wasTruncated = true
        }
        let selected = Array(ranked.prefix(limit))
        let booksByID = Dictionary(
            uniqueKeysWithValues: try graphBooks(ids: selected.map(\.bookID)).map { ($0.id, $0) }
        )
        let neighbors = try selected.map { candidate in
            guard let book = booksByID[candidate.bookID] else {
                throw GraphBuildError.invalidRelationshipData
            }
            return GraphNeighbor(book: book, evidence: candidate.evidence)
        }
        return GraphNeighborBatch(neighbors: neighbors, wasTruncated: wasTruncated)
    }

    private func sameAuthorEvidence(
        center: Book,
        limit: Int
    ) throws -> GraphEvidenceResult {
        let rows = try database.query(
            """
            SELECT id
            FROM books
            WHERE author = ? AND id != ?
            ORDER BY id ASC
            LIMIT ?
            """,
            bindings: [
                .text(center.author),
                .text(center.id.uuidString),
                .integer(Int64(limit + 1))
            ]
        ) { row -> UUID in
            guard let id = UUID(uuidString: row.string(at: 0) ?? "") else {
                throw GraphBuildError.invalidRelationshipData
            }
            return id
        }
        var values: [UUID: Set<GraphRelationEvidence>] = [:]
        for id in rows.prefix(limit) {
            values[id, default: []].insert(.sameAuthor(author: center.author))
        }
        return GraphEvidenceResult(values: values, wasTruncated: rows.count > limit)
    }

    private func sharedAssociationEvidence(
        bookID: UUID,
        joinTable: String,
        associationColumn: String,
        catalogTable: String,
        relation: (UUID, String) -> GraphRelationEvidence,
        limit: Int
    ) throws -> GraphEvidenceResult {
        let rows = try database.query(
            """
            WITH candidates AS (
                SELECT related.book_id AS book_id, COUNT(*) AS shared_count
                FROM \(joinTable) AS center
                JOIN \(joinTable) AS related
                  ON related.\(associationColumn) = center.\(associationColumn)
                WHERE center.book_id = ? AND related.book_id != ?
                GROUP BY related.book_id
                ORDER BY shared_count DESC, related.book_id ASC
                LIMIT ?
            )
            SELECT candidates.book_id, catalog.id, catalog.name, candidates.shared_count
            FROM candidates
            JOIN \(joinTable) AS related ON related.book_id = candidates.book_id
            JOIN \(joinTable) AS center
              ON center.book_id = ?
             AND center.\(associationColumn) = related.\(associationColumn)
            JOIN \(catalogTable) AS catalog
              ON catalog.id = related.\(associationColumn)
            ORDER BY candidates.shared_count DESC,
                     candidates.book_id ASC,
                     catalog.name COLLATE NOCASE ASC,
                     catalog.id ASC
            """,
            bindings: [
                .text(bookID.uuidString),
                .text(bookID.uuidString),
                .integer(Int64(limit + 1)),
                .text(bookID.uuidString)
            ]
        ) { row -> GraphAssociationRow in
            guard let relatedBookID = UUID(uuidString: row.string(at: 0) ?? ""),
                  let associationID = UUID(uuidString: row.string(at: 1) ?? ""),
                  let name = row.string(at: 2)
            else { throw GraphBuildError.invalidRelationshipData }
            return GraphAssociationRow(
                bookID: relatedBookID,
                associationID: associationID,
                name: name
            )
        }

        let orderedBookIDs = orderedUnique(rows.map(\.bookID))
        let retainedBookIDs = Set(orderedBookIDs.prefix(limit))
        var values: [UUID: Set<GraphRelationEvidence>] = [:]
        for row in rows where retainedBookIDs.contains(row.bookID) {
            values[row.bookID, default: []].insert(
                relation(row.associationID, row.name)
            )
        }
        return GraphEvidenceResult(
            values: values,
            wasTruncated: orderedBookIDs.count > limit
        )
    }

    private func manualRelationEvidence(
        bookID: UUID,
        limit: Int
    ) throws -> GraphEvidenceResult {
        let rows = try database.query(
            """
            WITH candidates AS (
                SELECT
                    CASE
                        WHEN source_book_id = ? THEN target_book_id
                        ELSE source_book_id
                    END AS other_book_id,
                    COUNT(*) AS relation_count
                FROM manual_book_relations
                WHERE source_book_id = ? OR target_book_id = ?
                GROUP BY other_book_id
                ORDER BY relation_count DESC, other_book_id ASC
                LIMIT ?
            )
            SELECT candidates.other_book_id,
                   relation.id,
                   relation.source_book_id,
                   relation.target_book_id,
                   relation.relation_kind,
                   relation.note
            FROM candidates
            JOIN manual_book_relations AS relation
              ON (
                    relation.source_book_id = ?
                AND relation.target_book_id = candidates.other_book_id
              ) OR (
                    relation.target_book_id = ?
                AND relation.source_book_id = candidates.other_book_id
              )
            ORDER BY candidates.relation_count DESC,
                     candidates.other_book_id ASC,
                     relation.created_at ASC,
                     relation.id ASC
            """,
            bindings: [
                .text(bookID.uuidString),
                .text(bookID.uuidString),
                .text(bookID.uuidString),
                .integer(Int64(limit + 1)),
                .text(bookID.uuidString),
                .text(bookID.uuidString)
            ]
        ) { row -> GraphManualRow in
            guard let otherBookID = UUID(uuidString: row.string(at: 0) ?? ""),
                  let relationID = UUID(uuidString: row.string(at: 1) ?? ""),
                  let sourceBookID = UUID(uuidString: row.string(at: 2) ?? ""),
                  let targetBookID = UUID(uuidString: row.string(at: 3) ?? ""),
                  let kind = ManualRelationKind(rawValue: row.string(at: 4) ?? ""),
                  sourceBookID != targetBookID
            else { throw GraphBuildError.invalidRelationshipData }
            return GraphManualRow(
                otherBookID: otherBookID,
                relationID: relationID,
                sourceBookID: sourceBookID,
                targetBookID: targetBookID,
                kind: kind,
                hasNote: row.string(at: 5) != nil
            )
        }

        let orderedBookIDs = orderedUnique(rows.map(\.otherBookID))
        let retainedBookIDs = Set(orderedBookIDs.prefix(limit))
        var values: [UUID: Set<GraphRelationEvidence>] = [:]
        for row in rows where retainedBookIDs.contains(row.otherBookID) {
            let edgeID = GraphEdgeID(row.sourceBookID, row.targetBookID)
            let direction: GraphManualDirection =
                row.sourceBookID == edgeID.firstBookID ? .firstToSecond : .secondToFirst
            values[row.otherBookID, default: []].insert(
                .manual(
                    relationID: row.relationID,
                    kind: row.kind,
                    direction: direction,
                    sourceBookID: row.sourceBookID,
                    targetBookID: row.targetBookID,
                    hasNote: row.hasNote
                )
            )
        }
        return GraphEvidenceResult(
            values: values,
            wasTruncated: orderedBookIDs.count > limit
        )
    }

    private func graphBooks(ids: [UUID]) throws -> [Book] {
        guard !ids.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        return try database.query(
            "SELECT \(bookColumns) FROM books WHERE id IN (\(placeholders)) ORDER BY id ASC",
            bindings: ids.map { .text($0.uuidString) },
            row: decodeBook
        )
    }

    private func merge(
        _ source: [UUID: Set<GraphRelationEvidence>],
        into destination: inout [UUID: Set<GraphRelationEvidence>]
    ) {
        for (bookID, evidence) in source {
            destination[bookID, default: []].formUnion(evidence)
        }
    }

    private func orderedUnique(_ values: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return values.filter { seen.insert($0).inserted }
    }
}

private struct GraphEvidenceResult {
    let values: [UUID: Set<GraphRelationEvidence>]
    let wasTruncated: Bool
}

private struct GraphAssociationRow {
    let bookID: UUID
    let associationID: UUID
    let name: String
}

private struct GraphManualRow {
    let otherBookID: UUID
    let relationID: UUID
    let sourceBookID: UUID
    let targetBookID: UUID
    let kind: ManualRelationKind
    let hasNote: Bool
}

private struct GraphRankedNeighbor {
    let bookID: UUID
    let evidence: [GraphRelationEvidence]
    let weight: Int
}
