import XCTest
@testable import BookAtlas

final class BookMergeTests: XCTestCase {
    func testMergePreviewIsReadOnlyAndNoConflictMergeFillsMissingFields() throws {
        let repository = try BookRepository.inMemory()
        let target = try repository.create(
            BookDraft(title: "《潮汐图谱》", author: "林雾"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(5)
        )
        let source = try repository.create(
            BookDraft(
                title: "《潮汐图谱》",
                originalTitle: "Tidal Atlas",
                author: "林雾",
                publisher: "虚构海岸出版社"
            ),
            at: FictionalLibraryFixtures.timestamp
        )

        let preview = try repository.mergePreview(targetID: target.id, sourceID: source.id)

        XCTAssertTrue(preview.conflictingFields.isEmpty)
        XCTAssertEqual(try repository.book(id: target.id), target)
        XCTAssertEqual(try repository.book(id: source.id), source)

        let result = try repository.mergeBooks(
            targetID: target.id,
            sourceID: source.id,
            selections: preview.defaultSelections,
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(10)
        )

        XCTAssertEqual(result.retainedBook.id, target.id)
        XCTAssertEqual(result.retainedBook.originalTitle, "Tidal Atlas")
        XCTAssertEqual(result.retainedBook.publisher, "虚构海岸出版社")
        XCTAssertEqual(result.retainedBook.createdAt, source.createdAt)
        XCTAssertNil(try repository.book(id: source.id))
    }

    func testMergeRetainsTargetIdentityAndUnionsAllExistingRelationships() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let repository = try BookRepository(database: database)
        let target = try repository.create(
            BookDraft(
                title: "《玻璃港》",
                author: "林雾",
                isbn: "9780000000002",
                readingStatus: .wishToRead,
                note: "目标备注"
            ),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(20)
        )
        let source = try repository.create(
            BookDraft(
                title: "玻璃港",
                originalTitle: "Glass Harbor",
                author: "林雾",
                publisher: "North Press",
                readingStatus: .read,
                note: "来源备注",
                startedAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(2),
                finishedAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(9)
            ),
            at: FictionalLibraryFixtures.timestamp
        )
        let third = try repository.create(
            BookDraft(title: "《灯塔手册》", author: "许岸"),
            at: FictionalLibraryFixtures.timestamp
        )
        let targetTag = try repository.createTag(try Tag(name: "目标标签", createdAt: FictionalLibraryFixtures.timestamp))
        let sourceTag = try repository.createTag(try Tag(name: "来源标签", createdAt: FictionalLibraryFixtures.timestamp))
        let collection = try repository.createCollection(
            try BookCollection(name: "港湾书单", createdAt: FictionalLibraryFixtures.timestamp)
        )
        let recommendation = try repository.createSource(
            try RecommendationSource(name: "虚构同好", createdAt: FictionalLibraryFixtures.timestamp)
        )
        try repository.attach(tagID: targetTag.id, toBookID: target.id)
        try repository.attach(tagID: sourceTag.id, toBookID: source.id)
        try repository.add(bookID: source.id, toCollectionID: collection.id)
        try repository.attach(sourceID: recommendation.id, toBookID: source.id)

        _ = try repository.addExternalLink(
            try ExternalLink(
                bookID: target.id,
                kind: .web,
                value: "https://example.invalid/glass",
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )
        _ = try repository.addExternalLink(
            try ExternalLink(
                bookID: source.id,
                kind: .web,
                label: "虚构书页",
                value: "https://example.invalid/glass",
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )
        _ = try repository.addExternalLink(
            try ExternalLink(
                bookID: source.id,
                kind: .web,
                label: "虚构资料",
                value: "https://example.invalid/notes",
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )

        _ = try repository.addManualRelation(
            try ManualBookRelation(
                sourceBookID: target.id,
                targetBookID: third.id,
                kind: .related,
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )
        _ = try repository.addManualRelation(
            try ManualBookRelation(
                sourceBookID: source.id,
                targetBookID: third.id,
                kind: .related,
                note: "共同背景",
                createdAt: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
            )
        )
        try repository.ignoreDuplicatePair(
            source.id,
            third.id,
            disposition: .separateTranslation,
            at: FictionalLibraryFixtures.timestamp
        )

        let preview = try repository.mergePreview(targetID: target.id, sourceID: source.id)
        XCTAssertTrue(preview.conflictingFields.contains(.readingStatus))
        XCTAssertTrue(preview.conflictingFields.contains(.note))
        XCTAssertEqual(preview.associations.sourceTags.map(\.id), [sourceTag.id])

        var selections = preview.defaultSelections
        selections[.readingStatus] = .source
        selections[.note] = .source
        let mergeDate = FictionalLibraryFixtures.timestamp.addingTimeInterval(100)
        let result = try repository.mergeBooks(
            targetID: target.id,
            sourceID: source.id,
            selections: selections,
            at: mergeDate
        )

        XCTAssertEqual(result.retainedBook.id, target.id)
        XCTAssertEqual(result.removedBookID, source.id)
        XCTAssertEqual(result.retainedBook.createdAt, source.createdAt)
        XCTAssertEqual(result.retainedBook.updatedAt, mergeDate)
        XCTAssertEqual(result.retainedBook.originalTitle, source.originalTitle)
        XCTAssertEqual(result.retainedBook.publisher, source.publisher)
        XCTAssertEqual(result.retainedBook.readingStatus, .read)
        XCTAssertEqual(result.retainedBook.note, "来源备注")
        XCTAssertEqual(result.retainedBook.startedAt, source.startedAt)
        XCTAssertEqual(result.retainedBook.finishedAt, source.finishedAt)
        XCTAssertNil(try repository.book(id: source.id))
        XCTAssertEqual(Set(try repository.tags(forBookID: target.id).map(\.id)), [targetTag.id, sourceTag.id])
        XCTAssertEqual(try repository.collections(forBookID: target.id).map(\.id), [collection.id])
        XCTAssertEqual(try repository.sources(forBookID: target.id).map(\.id), [recommendation.id])

        let links = try repository.externalLinks(forBookID: target.id)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links.first { $0.value.hasSuffix("/glass") }?.label, "虚构书页")
        XCTAssertEqual(Set(links.map(\.bookID)), [target.id])
        let relations = try repository.manualRelations(forBookID: target.id)
        XCTAssertEqual(relations.count, 1)
        XCTAssertEqual(relations[0].sourceBookID, target.id)
        XCTAssertEqual(relations[0].targetBookID, third.id)
        XCTAssertEqual(relations[0].note, "共同背景")
        XCTAssertEqual(
            try repository.ignoredDuplicatePair(between: target.id, and: third.id)?.disposition,
            .separateTranslation
        )
    }

    func testMergeRejectsRelationThatWouldBecomeSelfReferentialWithoutChangingBooks() throws {
        let repository = try BookRepository.inMemory()
        let target = try repository.create(
            BookDraft(title: "A101", author: "Author A"),
            at: FictionalLibraryFixtures.timestamp
        )
        let source = try repository.create(
            BookDraft(title: "A101", author: "Author A"),
            at: FictionalLibraryFixtures.timestamp
        )
        _ = try repository.addManualRelation(
            try ManualBookRelation(
                sourceBookID: source.id,
                targetBookID: target.id,
                kind: .related,
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )

        XCTAssertThrowsError(
            try repository.mergeBooks(
                targetID: target.id,
                sourceID: source.id,
                selections: BookMergeSelections(),
                at: FictionalLibraryFixtures.timestamp
            )
        ) { error in
            XCTAssertEqual(error as? BookMergeError, .selfRelationConflict)
        }
        XCTAssertEqual(try repository.book(id: target.id), target)
        XCTAssertEqual(try repository.book(id: source.id), source)
    }

    func testMergeFailureRollsBackFieldsMembershipsLinksAndSourceDeletion() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        let repository = try BookRepository(database: database)
        let target = try repository.create(
            BookDraft(title: "《星图索引》", author: "沈遥", note: "保留"),
            at: FictionalLibraryFixtures.timestamp
        )
        let source = try repository.create(
            BookDraft(title: "星图索引", author: "沈遥", note: "来源"),
            at: FictionalLibraryFixtures.timestamp.addingTimeInterval(1)
        )
        let tag = try repository.createTag(try Tag(name: "回滚标签", createdAt: FictionalLibraryFixtures.timestamp))
        try repository.attach(tagID: tag.id, toBookID: source.id)
        _ = try repository.addExternalLink(
            try ExternalLink(
                bookID: source.id,
                kind: .web,
                value: "https://example.invalid/rollback",
                createdAt: FictionalLibraryFixtures.timestamp
            )
        )
        try database.execute(
            """
            CREATE TRIGGER force_merge_failure
            BEFORE DELETE ON books
            WHEN OLD.id = '\(source.id.uuidString)'
            BEGIN
                SELECT RAISE(ABORT, 'fictional merge failure');
            END
            """
        )
        var selections = BookMergeSelections()
        selections[.note] = .source

        XCTAssertThrowsError(
            try repository.mergeBooks(
                targetID: target.id,
                sourceID: source.id,
                selections: selections,
                at: FictionalLibraryFixtures.timestamp.addingTimeInterval(5)
            )
        )
        XCTAssertEqual(try repository.book(id: target.id), target)
        XCTAssertEqual(try repository.book(id: source.id), source)
        XCTAssertEqual(try repository.tags(forBookID: target.id), [])
        XCTAssertEqual(try repository.tags(forBookID: source.id).map(\.id), [tag.id])
        XCTAssertEqual(try repository.externalLinks(forBookID: target.id), [])
        XCTAssertEqual(try repository.externalLinks(forBookID: source.id).count, 1)
    }
}
