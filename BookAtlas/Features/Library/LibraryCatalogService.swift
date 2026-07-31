import Foundation

enum CatalogServiceError: Error, Equatable {
    case nameConflict
    case invalidMerge
}

protocol LibraryCataloging: Actor {
    func queryBooks(_ query: LibraryQuery) throws -> [Book]
    func queryBookPage(_ query: LibraryQuery) throws -> LibraryPage
    func queryBookPage(
        _ query: LibraryQuery,
        focusedBookID: UUID
    ) async throws -> FocusedLibraryPage
    func createBook(from editor: BookEditorDraft) throws -> Book
    func updateBook(_ book: Book, from editor: BookEditorDraft) throws -> Book
    func deleteBook(_ book: Book) throws
    func duplicateCandidates(
        for editor: BookEditorDraft,
        proposedID: UUID,
        includingPossible: Bool
    ) throws -> [DuplicateCandidate]
    func duplicateCandidates(for book: Book, includingPossible: Bool) throws -> [DuplicateCandidate]
    func duplicateCandidateSearch(
        for editor: BookEditorDraft,
        proposedID: UUID,
        includingPossible: Bool
    ) throws -> DuplicateCandidateSearchResult
    func duplicateCandidateSearch(
        for book: Book,
        includingPossible: Bool
    ) throws -> DuplicateCandidateSearchResult
    func createBookKeepingIndependent(
        from editor: BookEditorDraft,
        proposedID: UUID,
        candidateID: UUID,
        disposition: DuplicatePairDisposition
    ) throws -> Book
    func ignoreDuplicatePair(
        _ firstBookID: UUID,
        _ secondBookID: UUID,
        disposition: DuplicatePairDisposition
    ) throws
    func mergePreview(targetID: UUID, sourceID: UUID) throws -> BookMergePreview
    func mergePreview(
        targetID: UUID,
        sourceEditor: BookEditorDraft,
        proposedSourceID: UUID
    ) throws -> BookMergePreview
    func mergeBooks(
        targetID: UUID,
        sourceID: UUID,
        selections: BookMergeSelections
    ) throws -> BookMergeResult
    func mergeNewBook(
        targetID: UUID,
        sourceEditor: BookEditorDraft,
        proposedSourceID: UUID,
        selections: BookMergeSelections
    ) throws -> BookMergeResult

    func catalogSnapshot() throws -> CatalogSnapshot
    func membership(for bookID: UUID) throws -> BookMembership
    func setAssociation(_ association: BookAssociation, included: Bool, bookID: UUID) throws

    func createTag(name: String) throws -> Tag
    func renameTag(_ tag: Tag, name: String) throws -> Tag
    func deleteTag(_ tag: Tag) throws
    func mergeTag(_ source: Tag, into target: Tag) throws

    func createCollection(name: String, description: String?) throws -> BookCollection
    func renameCollection(_ collection: BookCollection, name: String, description: String?) throws -> BookCollection
    func deleteCollection(_ collection: BookCollection) throws

    func createSource(name: String, details: String?) throws -> RecommendationSource
    func renameSource(_ source: RecommendationSource, name: String, details: String?) throws -> RecommendationSource
    func deleteSource(_ source: RecommendationSource) throws
    func externalLinks(for bookID: UUID) throws -> [ExternalLink]
    func addExternalLink(_ link: ExternalLink) throws -> ExternalLink
    func updateExternalLink(_ link: ExternalLink) throws
    func deleteExternalLink(_ id: UUID) throws
    func localFileReferences(for bookID: UUID) throws -> [LocalFileReference]
    func addLocalFileReference(_ reference: LocalFileReference) throws -> LocalFileReference
    func updateLocalFileReference(_ reference: LocalFileReference) throws
    func deleteLocalFileReference(_ id: UUID) throws
    func localGraph(
        centerBookID: UUID,
        options: GraphBuildOptions
    ) throws -> GraphScene
    func graphContentRevision() -> GraphContentRevision
    func graphContentRevisions() -> AsyncStream<GraphContentRevision>
    func addManualRelation(_ relation: ManualBookRelation) throws -> ManualBookRelation
    func deleteManualRelation(_ relation: ManualBookRelation) throws
    func prepareImport(from url: URL, mapping: CSVFieldMapping?) throws -> ImportPreview
    func executeImport(_ preview: ImportPreview) throws -> ImportResult
    func discardImport(_ preview: ImportPreview)
    func exportCSV(to url: URL) throws
    func exportMarkdown(to url: URL) throws
    func exportImportErrors(_ report: ImportErrorReport, to url: URL) throws
    func discardImportErrors(_ report: ImportErrorReport)
    func createBackup(at url: URL) throws -> BackupResult
    func inspectBackup(at url: URL) throws -> BackupPreview
    func restoreBackup(
        at url: URL,
        control: RestoreOperationControl,
        progress: @escaping @Sendable (RestoreProgressPhase) -> Void
    ) throws -> BackupPreview
}

extension LibraryCataloging {
    func duplicateCandidates(
        for editor: BookEditorDraft,
        proposedID: UUID,
        includingPossible: Bool
    ) throws -> [DuplicateCandidate] {
        []
    }
    func duplicateCandidates(for book: Book, includingPossible: Bool) throws -> [DuplicateCandidate] { [] }
    func duplicateCandidateSearch(
        for editor: BookEditorDraft,
        proposedID: UUID,
        includingPossible: Bool
    ) throws -> DuplicateCandidateSearchResult {
        DuplicateCandidateSearchResult(
            candidates: try duplicateCandidates(
                for: editor,
                proposedID: proposedID,
                includingPossible: includingPossible
            ),
            possibleLookupWasTruncated: false
        )
    }
    func duplicateCandidateSearch(
        for book: Book,
        includingPossible: Bool
    ) throws -> DuplicateCandidateSearchResult {
        DuplicateCandidateSearchResult(
            candidates: try duplicateCandidates(for: book, includingPossible: includingPossible),
            possibleLookupWasTruncated: false
        )
    }
    func createBookKeepingIndependent(
        from editor: BookEditorDraft,
        proposedID: UUID,
        candidateID: UUID,
        disposition: DuplicatePairDisposition
    ) throws -> Book {
        throw BookRepositoryError.entityNotFound
    }
    func ignoreDuplicatePair(
        _ firstBookID: UUID,
        _ secondBookID: UUID,
        disposition: DuplicatePairDisposition
    ) throws {
        throw BookRepositoryError.entityNotFound
    }
    func mergePreview(targetID: UUID, sourceID: UUID) throws -> BookMergePreview {
        throw BookMergeError.bookNotFound
    }
    func mergePreview(
        targetID: UUID,
        sourceEditor: BookEditorDraft,
        proposedSourceID: UUID
    ) throws -> BookMergePreview {
        throw BookMergeError.bookNotFound
    }
    func mergeBooks(
        targetID: UUID,
        sourceID: UUID,
        selections: BookMergeSelections
    ) throws -> BookMergeResult {
        throw BookMergeError.bookNotFound
    }
    func mergeNewBook(
        targetID: UUID,
        sourceEditor: BookEditorDraft,
        proposedSourceID: UUID,
        selections: BookMergeSelections
    ) throws -> BookMergeResult {
        throw BookMergeError.bookNotFound
    }
    func catalogSnapshot() throws -> CatalogSnapshot { .empty }
    func membership(for bookID: UUID) throws -> BookMembership { .empty }
    func setAssociation(_ association: BookAssociation, included: Bool, bookID: UUID) throws {
        throw BookRepositoryError.entityNotFound
    }
    func createTag(name: String) throws -> Tag { throw BookRepositoryError.entityNotFound }
    func renameTag(_ tag: Tag, name: String) throws -> Tag { throw BookRepositoryError.entityNotFound }
    func deleteTag(_ tag: Tag) throws { throw BookRepositoryError.entityNotFound }
    func mergeTag(_ source: Tag, into target: Tag) throws { throw BookRepositoryError.invalidMerge }
    func createCollection(name: String, description: String?) throws -> BookCollection {
        throw BookRepositoryError.entityNotFound
    }
    func renameCollection(
        _ collection: BookCollection,
        name: String,
        description: String?
    ) throws -> BookCollection {
        throw BookRepositoryError.entityNotFound
    }
    func deleteCollection(_ collection: BookCollection) throws { throw BookRepositoryError.entityNotFound }
    func createSource(name: String, details: String?) throws -> RecommendationSource {
        throw BookRepositoryError.entityNotFound
    }
    func renameSource(
        _ source: RecommendationSource,
        name: String,
        details: String?
    ) throws -> RecommendationSource {
        throw BookRepositoryError.entityNotFound
    }
    func deleteSource(_ source: RecommendationSource) throws { throw BookRepositoryError.entityNotFound }
    func externalLinks(for bookID: UUID) throws -> [ExternalLink] { [] }
    func addExternalLink(_ link: ExternalLink) throws -> ExternalLink {
        throw BookRepositoryError.entityNotFound
    }
    func updateExternalLink(_ link: ExternalLink) throws {
        throw BookRepositoryError.entityNotFound
    }
    func deleteExternalLink(_ id: UUID) throws {
        throw BookRepositoryError.entityNotFound
    }
    func localFileReferences(for bookID: UUID) throws -> [LocalFileReference] { [] }
    func addLocalFileReference(_ reference: LocalFileReference) throws -> LocalFileReference {
        throw BookRepositoryError.entityNotFound
    }
    func updateLocalFileReference(_ reference: LocalFileReference) throws {
        throw BookRepositoryError.entityNotFound
    }
    func deleteLocalFileReference(_ id: UUID) throws {
        throw BookRepositoryError.entityNotFound
    }
    func localGraph(
        centerBookID: UUID,
        options: GraphBuildOptions
    ) throws -> GraphScene {
        throw GraphBuildError.databaseUnavailable
    }
    func graphContentRevision() -> GraphContentRevision { .initial }
    func graphContentRevisions() -> AsyncStream<GraphContentRevision> {
        AsyncStream { continuation in
            continuation.yield(.initial)
        }
    }
    func addManualRelation(_ relation: ManualBookRelation) throws -> ManualBookRelation {
        throw BookRepositoryError.entityNotFound
    }
    func deleteManualRelation(_ relation: ManualBookRelation) throws {
        throw BookRepositoryError.entityNotFound
    }
    func prepareImport(from url: URL, mapping: CSVFieldMapping?) throws -> ImportPreview {
        throw PortabilityError.unsafeFile
    }
    func executeImport(_ preview: ImportPreview) throws -> ImportResult {
        throw PortabilityError.unsafeFile
    }
    func discardImport(_ preview: ImportPreview) {}
    func exportCSV(to url: URL) throws { throw PortabilityError.unsafeFile }
    func exportMarkdown(to url: URL) throws { throw PortabilityError.unsafeFile }
    func exportImportErrors(_ report: ImportErrorReport, to url: URL) throws {
        throw PortabilityError.unsafeFile
    }
    func discardImportErrors(_ report: ImportErrorReport) {}
    func createBackup(at url: URL) throws -> BackupResult { throw PortabilityError.unsafeFile }
    func inspectBackup(at url: URL) throws -> BackupPreview { throw PortabilityError.unsafeFile }
    func restoreBackup(
        at url: URL,
        control: RestoreOperationControl,
        progress: @escaping @Sendable (RestoreProgressPhase) -> Void
    ) throws -> BackupPreview {
        throw PortabilityError.unsafeFile
    }
}

actor LibraryCatalogService: LibraryCataloging {
    private var repository: BookRepository
    private let databaseURL: URL?
    private let recoveryDirectory: URL?
    private let now: @Sendable () -> Date
    private var contentRevision = GraphContentRevision.initial
    private var revisionContinuations: [
        UUID: AsyncStream<GraphContentRevision>.Continuation
    ] = [:]

    init(
        repository: BookRepository,
        databaseURL: URL? = nil,
        recoveryDirectory: URL? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.databaseURL = databaseURL
        self.recoveryDirectory = recoveryDirectory
        self.now = now
    }

    func close() throws {
        try repository.close()
    }

    func queryBooks(_ query: LibraryQuery) throws -> [Book] {
        try repository.query(query)
    }

    func queryBookPage(_ query: LibraryQuery) throws -> LibraryPage {
        try repository.queryPage(query)
    }

    func queryBookPage(
        _ query: LibraryQuery,
        focusedBookID: UUID
    ) async throws -> FocusedLibraryPage {
        try repository.queryPage(query, focusedBookID: focusedBookID)
    }

    func createBook(from editor: BookEditorDraft) throws -> Book {
        let book = try repository.create(editor.makeBookDraft(), at: now())
        markGraphContentChanged()
        return book
    }

    func updateBook(_ book: Book, from editor: BookEditorDraft) throws -> Book {
        let updated = try book.applying(editor.makeBookDraft(), at: now())
        try repository.update(updated)
        markGraphContentChanged()
        return updated
    }

    func deleteBook(_ book: Book) throws {
        try repository.deleteBook(id: book.id)
        markGraphContentChanged()
    }

    func duplicateCandidates(
        for editor: BookEditorDraft,
        proposedID: UUID,
        includingPossible: Bool
    ) throws -> [DuplicateCandidate] {
        try repository.duplicateCandidates(
            for: DuplicateProbe(id: proposedID, draft: editor.makeBookDraft()),
            includingPossible: includingPossible
        )
    }

    func duplicateCandidateSearch(
        for editor: BookEditorDraft,
        proposedID: UUID,
        includingPossible: Bool
    ) throws -> DuplicateCandidateSearchResult {
        try repository.duplicateCandidateSearch(
            for: DuplicateProbe(id: proposedID, draft: editor.makeBookDraft()),
            includingPossible: includingPossible
        )
    }

    func duplicateCandidates(
        for book: Book,
        includingPossible: Bool
    ) throws -> [DuplicateCandidate] {
        try repository.duplicateCandidates(
            for: DuplicateProbe(book: book),
            includingPossible: includingPossible
        )
    }

    func duplicateCandidateSearch(
        for book: Book,
        includingPossible: Bool
    ) throws -> DuplicateCandidateSearchResult {
        try repository.duplicateCandidateSearch(
            for: DuplicateProbe(book: book),
            includingPossible: includingPossible
        )
    }

    func createBookKeepingIndependent(
        from editor: BookEditorDraft,
        proposedID: UUID,
        candidateID: UUID,
        disposition: DuplicatePairDisposition
    ) throws -> Book {
        let draft = try editor.makeBookDraft()
        let book = try repository.transaction {
            let book = try repository.create(draft, id: proposedID, at: now())
            if candidateID != book.id {
                try repository.ignoreDuplicatePair(
                    book.id,
                    candidateID,
                    disposition: disposition,
                    at: now()
                )
            }
            return book
        }
        markGraphContentChanged()
        return book
    }

    func ignoreDuplicatePair(
        _ firstBookID: UUID,
        _ secondBookID: UUID,
        disposition: DuplicatePairDisposition
    ) throws {
        try repository.ignoreDuplicatePair(
            firstBookID,
            secondBookID,
            disposition: disposition,
            at: now()
        )
    }

    func mergePreview(targetID: UUID, sourceID: UUID) throws -> BookMergePreview {
        try repository.mergePreview(targetID: targetID, sourceID: sourceID)
    }

    func mergePreview(
        targetID: UUID,
        sourceEditor: BookEditorDraft,
        proposedSourceID: UUID
    ) throws -> BookMergePreview {
        let source = try Book(
            id: proposedSourceID,
            draft: sourceEditor.makeBookDraft(),
            createdAt: now()
        )
        return try repository.mergePreview(targetID: targetID, transientSource: source)
    }

    func mergeBooks(
        targetID: UUID,
        sourceID: UUID,
        selections: BookMergeSelections
    ) throws -> BookMergeResult {
        let result = try repository.mergeBooks(
            targetID: targetID,
            sourceID: sourceID,
            selections: selections,
            at: now()
        )
        markGraphContentChanged()
        return result
    }

    func mergeNewBook(
        targetID: UUID,
        sourceEditor: BookEditorDraft,
        proposedSourceID: UUID,
        selections: BookMergeSelections
    ) throws -> BookMergeResult {
        let draft = try sourceEditor.makeBookDraft()
        let result = try repository.transaction {
            _ = try repository.create(draft, id: proposedSourceID, at: now())
            return try repository.mergeBooks(
                targetID: targetID,
                sourceID: proposedSourceID,
                selections: selections,
                at: now()
            )
        }
        markGraphContentChanged()
        return result
    }

    func catalogSnapshot() throws -> CatalogSnapshot {
        CatalogSnapshot(
            tags: try repository.tagSummaries(),
            collections: try repository.collectionSummaries(),
            sources: try repository.sourceSummaries()
        )
    }

    func membership(for bookID: UUID) throws -> BookMembership {
        try repository.membership(forBookID: bookID)
    }

    func setAssociation(_ association: BookAssociation, included: Bool, bookID: UUID) throws {
        switch association {
        case let .tag(id):
            if included {
                try repository.attach(tagID: id, toBookID: bookID)
            } else {
                try repository.detach(tagID: id, fromBookID: bookID)
            }
        case let .collection(id):
            if included {
                try repository.add(bookID: bookID, toCollectionID: id)
            } else {
                try repository.remove(bookID: bookID, fromCollectionID: id)
            }
        case let .source(id):
            if included {
                try repository.attach(sourceID: id, toBookID: bookID)
            } else {
                try repository.detach(sourceID: id, fromBookID: bookID)
            }
        }
        markGraphContentChanged()
    }

    func createTag(name: String) throws -> Tag {
        let tag = try Tag(name: name, createdAt: now())
        try ensureUnique(name: tag.name, excluding: nil, existing: repository.tagSummaries().map { ($0.id, $0.tag.name) })
        let created = try repository.createTag(tag)
        markGraphContentChanged()
        return created
    }

    func renameTag(_ tag: Tag, name: String) throws -> Tag {
        let updated = try Tag(id: tag.id, name: name, createdAt: tag.createdAt, updatedAt: now())
        try ensureUnique(
            name: updated.name,
            excluding: tag.id,
            existing: repository.tagSummaries().map { ($0.id, $0.tag.name) }
        )
        try repository.updateTag(updated)
        markGraphContentChanged()
        return updated
    }

    func deleteTag(_ tag: Tag) throws {
        try repository.deleteTag(id: tag.id)
        markGraphContentChanged()
    }

    func mergeTag(_ source: Tag, into target: Tag) throws {
        guard source.id != target.id else {
            throw CatalogServiceError.invalidMerge
        }
        try repository.mergeTag(sourceID: source.id, into: target.id)
        markGraphContentChanged()
    }

    func createCollection(name: String, description: String?) throws -> BookCollection {
        let collection = try BookCollection(name: name, description: description, createdAt: now())
        try ensureUnique(
            name: collection.name,
            excluding: nil,
            existing: repository.collectionSummaries().map { ($0.id, $0.collection.name) }
        )
        let created = try repository.createCollection(collection)
        markGraphContentChanged()
        return created
    }

    func renameCollection(
        _ collection: BookCollection,
        name: String,
        description: String?
    ) throws -> BookCollection {
        let updated = try BookCollection(
            id: collection.id,
            name: name,
            description: description,
            createdAt: collection.createdAt,
            updatedAt: now()
        )
        try ensureUnique(
            name: updated.name,
            excluding: collection.id,
            existing: repository.collectionSummaries().map { ($0.id, $0.collection.name) }
        )
        try repository.updateCollection(updated)
        markGraphContentChanged()
        return updated
    }

    func deleteCollection(_ collection: BookCollection) throws {
        try repository.deleteCollection(id: collection.id)
        markGraphContentChanged()
    }

    func createSource(name: String, details: String?) throws -> RecommendationSource {
        let source = try RecommendationSource(name: name, details: details, createdAt: now())
        try ensureUnique(
            name: source.name,
            excluding: nil,
            existing: repository.sourceSummaries().map { ($0.id, $0.source.name) }
        )
        let created = try repository.createSource(source)
        markGraphContentChanged()
        return created
    }

    func renameSource(
        _ source: RecommendationSource,
        name: String,
        details: String?
    ) throws -> RecommendationSource {
        let updated = try RecommendationSource(
            id: source.id,
            name: name,
            details: details,
            createdAt: source.createdAt,
            updatedAt: now()
        )
        try ensureUnique(
            name: updated.name,
            excluding: source.id,
            existing: repository.sourceSummaries().map { ($0.id, $0.source.name) }
        )
        try repository.updateSource(updated)
        markGraphContentChanged()
        return updated
    }

    func deleteSource(_ source: RecommendationSource) throws {
        try repository.deleteSource(id: source.id)
        markGraphContentChanged()
    }

    func externalLinks(for bookID: UUID) throws -> [ExternalLink] {
        try repository.externalLinks(forBookID: bookID)
    }

    func addExternalLink(_ link: ExternalLink) throws -> ExternalLink {
        try repository.addExternalLink(link)
    }

    func updateExternalLink(_ link: ExternalLink) throws {
        try repository.updateExternalLink(link)
    }

    func deleteExternalLink(_ id: UUID) throws {
        try repository.deleteExternalLink(id: id)
    }

    func localFileReferences(for bookID: UUID) throws -> [LocalFileReference] {
        try repository.localFileReferences(forBookID: bookID)
    }

    func addLocalFileReference(_ reference: LocalFileReference) throws -> LocalFileReference {
        try repository.addLocalFileReference(reference)
    }

    func updateLocalFileReference(_ reference: LocalFileReference) throws {
        try repository.updateLocalFileReference(reference)
    }

    func deleteLocalFileReference(_ id: UUID) throws {
        try repository.deleteLocalFileReference(id: id)
    }

    func addManualRelation(_ relation: ManualBookRelation) throws -> ManualBookRelation {
        let created = try repository.addManualRelation(relation)
        markGraphContentChanged()
        return created
    }

    func deleteManualRelation(_ relation: ManualBookRelation) throws {
        try repository.deleteManualRelation(id: relation.id)
        markGraphContentChanged()
    }

    func graphContentRevision() -> GraphContentRevision {
        contentRevision
    }

    func graphContentRevisions() -> AsyncStream<GraphContentRevision> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<GraphContentRevision>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        revisionContinuations[id] = continuation
        continuation.yield(contentRevision)
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.removeRevisionContinuation(id)
            }
        }
        return stream
    }

    func localGraph(
        centerBookID: UUID,
        options: GraphBuildOptions
    ) throws -> GraphScene {
        let clock = ContinuousClock()
        var queryDuration = Duration.zero
        let cancellation = GraphBuildCancellation(
            isCancelled: {
                withUnsafeCurrentTask { $0?.isCancelled ?? false }
            }
        )
        let projectionStart = clock.now
        let snapshot = try LocalGraphBuilder().build(
            centerBookID: centerBookID,
            options: options,
            cancellation: cancellation,
            book: { id in
                let start = clock.now
                defer { queryDuration += start.duration(to: clock.now) }
                return try repository.book(id: id)
            },
            neighbors: { id, relationTypes, limit in
                let start = clock.now
                defer { queryDuration += start.duration(to: clock.now) }
                return try repository.graphNeighbors(
                    for: id,
                    relationTypes: relationTypes,
                    limit: limit
                )
            }
        )
        let projectionDuration =
            projectionStart.duration(to: clock.now) - queryDuration
        let layoutStart = clock.now
        let layout = try DeterministicGraphLayout().layout(
            snapshot: snapshot,
            cancellation: cancellation
        )
        let layoutDuration = layoutStart.duration(to: clock.now)
        return GraphScene(
            snapshot: snapshot,
            layout: layout,
            metrics: GraphSceneMetrics(
                querySeconds: queryDuration.secondsValue,
                projectionSeconds: max(0, projectionDuration.secondsValue),
                layoutSeconds: layoutDuration.secondsValue
            ),
            contentRevision: contentRevision
        )
    }

    func prepareImport(from url: URL, mapping: CSVFieldMapping?) throws -> ImportPreview {
        try LibraryImportCoordinator().prepare(
            url: url,
            mapping: mapping,
            repository: repository,
            cancellation: ImportCancellation(
                isCancelled: {
                    withUnsafeCurrentTask { $0?.isCancelled ?? false }
                }
            )
        )
    }

    func executeImport(_ preview: ImportPreview) throws -> ImportResult {
        let result = try LibraryImportCoordinator().execute(
            preview: preview,
            repository: repository,
            at: now(),
            cancellation: ImportCancellation(
                isCancelled: {
                    withUnsafeCurrentTask { task in
                        task?.isCancelled ?? false
                    }
                }
            )
        )
        markGraphContentChanged()
        return result
    }

    func discardImport(_ preview: ImportPreview) {
        LibraryImportCoordinator().discard(preview)
    }

    func exportCSV(to url: URL) throws {
        try LibraryExportCoordinator(now: now).exportCSV(repository: repository, to: url)
    }

    func exportMarkdown(to url: URL) throws {
        try LibraryExportCoordinator(now: now).exportMarkdown(repository: repository, to: url)
    }

    func exportImportErrors(_ report: ImportErrorReport, to url: URL) throws {
        try LibraryExportCoordinator(now: now).exportErrorReport(report, to: url)
    }

    func discardImportErrors(_ report: ImportErrorReport) {
        LibraryExportCoordinator(now: now).discardErrorReport(report)
    }

    func createBackup(at url: URL) throws -> BackupResult {
        try backupCoordinator().backup(
            repository: repository,
            to: url,
            cancellation: RestoreCancellation(
                isCancelled: {
                    withUnsafeCurrentTask { $0?.isCancelled ?? false }
                }
            )
        )
    }

    func inspectBackup(at url: URL) throws -> BackupPreview {
        try backupCoordinator().inspect(
            url,
            cancellation: RestoreCancellation(
                isCancelled: {
                    withUnsafeCurrentTask { $0?.isCancelled ?? false }
                }
            )
        )
    }

    func restoreBackup(
        at url: URL,
        control: RestoreOperationControl,
        progress: @escaping @Sendable (RestoreProgressPhase) -> Void
    ) throws -> BackupPreview {
        guard let databaseURL else { throw PortabilityError.unsafeFile }
        let recoveryDirectory = self.recoveryDirectory
            ?? databaseURL.deletingLastPathComponent().appendingPathComponent(
                "Recovery Copies",
                isDirectory: true
            )
        let preview = try backupCoordinator().restore(
            backupURL: url,
            databaseURL: databaseURL,
            repository: &repository,
            recoveryDirectory: recoveryDirectory,
            control: control,
            cancellation: RestoreCancellation(
                isCancelled: {
                    control.isCancellationRequested
                }
            ),
            progress: progress
        )
        markGraphContentChanged()
        return preview
    }

    private func markGraphContentChanged() {
        contentRevision = contentRevision.advanced()
        for continuation in revisionContinuations.values {
            continuation.yield(contentRevision)
        }
    }

    private func removeRevisionContinuation(_ id: UUID) {
        revisionContinuations.removeValue(forKey: id)
    }

    private func backupCoordinator() -> LibraryBackupCoordinator {
        LibraryBackupCoordinator(
            applicationVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "development",
            now: now
        )
    }

    private func ensureUnique(
        name: String,
        excluding excludedID: UUID?,
        existing: [(UUID, String)]
    ) throws {
        let key = try CatalogNameNormalizer.comparisonKey(name)
        for (id, existingName) in existing where id != excludedID {
            if try CatalogNameNormalizer.comparisonKey(existingName) == key {
                throw CatalogServiceError.nameConflict
            }
        }
    }
}
