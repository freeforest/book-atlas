import Foundation

enum PerformanceLibraryError: Error, Equatable {
    case invalidArguments
    case unsupportedBookCount
    case unsafeTemporaryLocation
    case missingDatabase
    case unexpectedTemporaryArtifact
}

enum PerformanceLibraryCommand: Equatable {
    case prepare(sessionID: UUID, bookCount: Int)
    case useExisting(sessionID: UUID)
    case cleanup(sessionID: UUID)

    private static let prepareFlag = "-BookAtlasPerformancePrepareLibrary"
    private static let useFlag = "-BookAtlasPerformanceUseExistingLibrary"
    private static let cleanupFlag = "-BookAtlasPerformanceCleanupLibrary"

    static func parse(arguments: [String]) throws -> PerformanceLibraryCommand? {
        let performanceFlags = arguments.filter {
            $0.hasPrefix("-BookAtlasPerformance")
        }
        guard !performanceFlags.isEmpty else {
            return nil
        }
        guard performanceFlags.count == 1,
              let flag = performanceFlags.first,
              let index = arguments.firstIndex(of: flag)
        else {
            throw PerformanceLibraryError.invalidArguments
        }

        switch flag {
        case prepareFlag:
            guard arguments.indices.contains(index + 2),
                  let sessionID = canonicalSessionID(arguments[index + 1]),
                  let bookCount = canonicalBookCount(arguments[index + 2])
            else {
                throw PerformanceLibraryError.invalidArguments
            }
            return .prepare(sessionID: sessionID, bookCount: bookCount)
        case useFlag:
            guard arguments.indices.contains(index + 1),
                  let sessionID = canonicalSessionID(arguments[index + 1])
            else {
                throw PerformanceLibraryError.invalidArguments
            }
            return .useExisting(sessionID: sessionID)
        case cleanupFlag:
            guard arguments.indices.contains(index + 1),
                  let sessionID = canonicalSessionID(arguments[index + 1])
            else {
                throw PerformanceLibraryError.invalidArguments
            }
            return .cleanup(sessionID: sessionID)
        default:
            throw PerformanceLibraryError.invalidArguments
        }
    }

    private static func canonicalSessionID(_ value: String) -> UUID? {
        guard value.count == 36,
              let identifier = UUID(uuidString: value),
              value.caseInsensitiveCompare(identifier.uuidString) == .orderedSame
        else {
            return nil
        }
        return identifier
    }

    private static func canonicalBookCount(_ value: String) -> Int? {
        guard let count = Int(value),
              String(count) == value,
              [1_000, 5_000, 10_000].contains(count)
        else {
            return nil
        }
        return count
    }
}

/// Owns the path-free, test-only lifecycle for an existing-library launch
/// benchmark. A caller supplies only an opaque UUID; all files are derived
/// beneath the process temporary directory and never fall back to production
/// Application Support.
struct PerformanceLibrarySession {
    private static let directoryPrefix = "BookAtlas-Performance-"
    private static let databaseName = "library.sqlite"
    private static let allowedArtifactNames: Set<String> = [
        databaseName,
        "\(databaseName)-wal",
        "\(databaseName)-shm",
        "\(databaseName)-journal"
    ]

    let sessionID: UUID
    let temporaryRootURL: URL
    private let fileManager: FileManager

    init(
        sessionID: UUID,
        temporaryRootURL: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) {
        self.sessionID = sessionID
        self.temporaryRootURL = temporaryRootURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
        self.fileManager = fileManager
    }

    var directoryURL: URL {
        temporaryRootURL.appendingPathComponent(
            Self.directoryPrefix + sessionID.uuidString.lowercased(),
            isDirectory: true
        )
    }

    var databaseURL: URL {
        directoryURL.appendingPathComponent(
            Self.databaseName,
            isDirectory: false
        )
    }

    func prepare(bookCount: Int) throws -> URL {
        guard [1_000, 5_000, 10_000].contains(bookCount) else {
            throw PerformanceLibraryError.unsupportedBookCount
        }
        try validateContainment()
        try requireDirectory(at: temporaryRootURL)
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw PerformanceLibraryError.unsafeTemporaryLocation
        }

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        do {
            try requireDirectory(at: directoryURL)
            let repository = try BookRepository(databaseURL: databaseURL)
            do {
                try seed(repository: repository, bookCount: bookCount)
                guard repository.schemaVersion == BookAtlasSchema.latestVersion,
                      try repository.foreignKeyCheck(),
                      try repository.queryPage(LibraryQuery()).totalCount == bookCount
                else {
                    throw PerformanceLibraryError.missingDatabase
                }
                try repository.close()
            } catch {
                try? repository.close()
                throw error
            }
            _ = try validatedExistingDatabaseURL()
            return databaseURL
        } catch {
            try? removeCreatedSessionDirectory()
            throw error
        }
    }

    func validatedExistingDatabaseURL() throws -> URL {
        try validateContainment()
        try requireDirectory(at: temporaryRootURL)
        try requireDirectory(at: directoryURL)
        try validateArtifacts()
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw PerformanceLibraryError.missingDatabase
        }
        try requireRegularFile(at: databaseURL)
        return databaseURL
    }

    func cleanup() throws {
        try validateContainment()
        try requireDirectory(at: temporaryRootURL)
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }
        try requireDirectory(at: directoryURL)
        try validateArtifacts()

        for name in Self.allowedArtifactNames {
            let artifact = directoryURL.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: artifact.path) else {
                continue
            }
            try requireRegularFile(at: artifact)
            try fileManager.removeItem(at: artifact)
        }

        guard try fileManager.contentsOfDirectory(atPath: directoryURL.path).isEmpty else {
            throw PerformanceLibraryError.unexpectedTemporaryArtifact
        }
        try fileManager.removeItem(at: directoryURL)
    }

    private func validateContainment() throws {
        let root = temporaryRootURL.standardizedFileURL
        let directory = directoryURL.standardizedFileURL
        let database = databaseURL.standardizedFileURL
        guard directory.deletingLastPathComponent() == root,
              database.deletingLastPathComponent() == directory,
              directory.lastPathComponent
                == Self.directoryPrefix + sessionID.uuidString.lowercased(),
              database.lastPathComponent == Self.databaseName
        else {
            throw PerformanceLibraryError.unsafeTemporaryLocation
        }
    }

    private func validateArtifacts() throws {
        let artifacts = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: []
        )
        for artifact in artifacts {
            guard artifact.deletingLastPathComponent().standardizedFileURL
                    == directoryURL.standardizedFileURL,
                  Self.allowedArtifactNames.contains(artifact.lastPathComponent)
            else {
                throw PerformanceLibraryError.unexpectedTemporaryArtifact
            }
            try requireRegularFile(at: artifact)
        }
    }

    private func requireDirectory(at url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true, values.isDirectory == true else {
            throw PerformanceLibraryError.unsafeTemporaryLocation
        }
    }

    private func requireRegularFile(at url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw PerformanceLibraryError.unsafeTemporaryLocation
        }
    }

    private func removeCreatedSessionDirectory() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }
        try requireDirectory(at: directoryURL)
        try validateArtifacts()
        for name in Self.allowedArtifactNames {
            let artifact = directoryURL.appendingPathComponent(name)
            if fileManager.fileExists(atPath: artifact.path) {
                try requireRegularFile(at: artifact)
                try fileManager.removeItem(at: artifact)
            }
        }
        guard try fileManager.contentsOfDirectory(atPath: directoryURL.path).isEmpty else {
            throw PerformanceLibraryError.unexpectedTemporaryArtifact
        }
        try fileManager.removeItem(at: directoryURL)
    }

    private func seed(
        repository: BookRepository,
        bookCount: Int
    ) throws {
        let timestamp = Date(timeIntervalSince1970: 1_735_689_600)
        let tags = try (0 ..< 32).map { index in
            try repository.createTag(
                Tag(
                    id: deterministicID(namespace: 20, index: index),
                    name: String(format: "固定性能标签 %02d", index),
                    createdAt: timestamp
                )
            )
        }

        try repository.transaction {
            for index in 0 ..< bookCount {
                let book = try repository.create(
                    BookDraft(
                        title: String(format: "《固定性能书目 %05d》", index),
                        originalTitle: String(
                            format: "Synthetic Atlas %05d",
                            index
                        ),
                        author: "虚构作者 \(index % 97)",
                        readingStatus: ReadingStatus.allCases[
                            index % ReadingStatus.allCases.count
                        ],
                        priority: BookPriority(rawValue: (index % 5) + 1),
                        note: index.isMultiple(of: 11)
                            ? "固定虚构性能备注。"
                            : nil
                    ),
                    id: deterministicID(namespace: 10, index: index),
                    at: timestamp.addingTimeInterval(TimeInterval(index))
                )
                try repository.attach(
                    tagID: tags[index % tags.count].id,
                    toBookID: book.id
                )
            }
        }
    }

    private func deterministicID(namespace: Int, index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "%08d-0000-0000-0000-%012d",
                namespace,
                index
            )
        )!
    }
}
