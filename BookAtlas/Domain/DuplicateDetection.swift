import Foundation

enum ISBNValidationResult: Equatable, Sendable {
    case empty
    case valid(String)
    case invalid

    var validIdentifier: String? {
        guard case let .valid(value) = self else {
            return nil
        }
        return value
    }
}

enum DuplicateISBNNormalizer {
    static func validate(_ value: String?) -> ISBNValidationResult {
        guard let value else {
            return .empty
        }

        let compact = ISBNNormalizer.normalize(value)
        guard !compact.isEmpty else {
            return .empty
        }

        switch compact.count {
        case 10:
            return isValidISBN10(compact) ? .valid(compact) : .invalid
        case 13:
            return isValidISBN13(compact) ? .valid(compact) : .invalid
        default:
            return .invalid
        }
    }

    private static func isValidISBN10(_ value: String) -> Bool {
        let characters = Array(value)
        guard characters.prefix(9).allSatisfy(\.isNumber),
              characters[9].isNumber || characters[9] == "X"
        else {
            return false
        }

        var sum = 0
        for index in 0 ..< 10 {
            let digit: Int
            if index == 9, characters[index] == "X" {
                digit = 10
            } else {
                guard let parsed = characters[index].wholeNumberValue else {
                    return false
                }
                digit = parsed
            }
            sum += (10 - index) * digit
        }
        return sum.isMultiple(of: 11)
    }

    private static func isValidISBN13(_ value: String) -> Bool {
        let characters = Array(value)
        guard characters.allSatisfy(\.isNumber) else {
            return false
        }

        var sum = 0
        for index in 0 ..< 12 {
            guard let digit = characters[index].wholeNumberValue else {
                return false
            }
            sum += digit * (index.isMultiple(of: 2) ? 1 : 3)
        }
        guard let checkDigit = characters[12].wholeNumberValue else {
            return false
        }
        return (10 - (sum % 10)) % 10 == checkDigit
    }
}

enum DuplicateTextNormalizer {
    private static let locale = Locale(identifier: "en_US_POSIX")
    private static let subtitleSeparators = [":", "：", "—", "–", "－"]
    private static let titlePunctuation = [
        "《", "》", "〈", "〉", "「", "」", "『", "』", "“", "”", "‘", "’",
        "\"", "'", "，", ",", "。", ".", "！", "!", "？", "?", "；", ";", "、", "·",
        "（", "）", "(", ")", "【", "】", "[", "]"
    ]
    private static let authorSeparators = [",", "，", "、", ";", "；", "&", "＆", "/"]

    static func titleKey(_ value: String) -> String {
        var value = compatibilityFold(value)
        for separator in subtitleSeparators {
            value = value.replacingOccurrences(of: separator, with: " : ")
        }
        for punctuation in titlePunctuation {
            value = value.replacingOccurrences(of: punctuation, with: " ")
        }
        return collapseWhitespace(value)
    }

    static func authorKey(_ value: String) -> String {
        var value = compatibilityFold(value)
        for separator in authorSeparators {
            value = value.replacingOccurrences(of: separator, with: " ; ")
        }
        for punctuation in titlePunctuation where punctuation != ";" {
            value = value.replacingOccurrences(of: punctuation, with: " ")
        }
        // Contributor order is intentionally preserved. The first release does
        // not claim that free-form author strings can be safely reordered.
        return collapseWhitespace(value)
            .replacingOccurrences(of: " ; ", with: ";")
    }

    static func titleTokens(_ value: String) -> Set<String> {
        let normalized = titleKey(value)
        guard !normalized.isEmpty else {
            return []
        }

        let baseTitle = baseTitleKey(value)
        var tokens = Set(
            baseTitle
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
                .filter { $0.count >= 2 }
        )

        let compact = baseTitle.filter { !$0.isWhitespace }
        let characters = Array(compact)
        if characters.count >= 2 {
            for index in 0 ..< (characters.count - 1) {
                tokens.insert(String(characters[index ... index + 1]))
            }
        } else if !compact.isEmpty {
            tokens.insert(compact)
        }
        return tokens
    }

    static func baseTitleKey(_ value: String) -> String {
        let normalized = titleKey(value)
        let base = normalized.split(separator: ":", maxSplits: 1).first.map(String.init) ?? normalized
        return collapseWhitespace(base)
    }

    private static func compatibilityFold(_ value: String) -> String {
        value
            .precomposedStringWithCompatibilityMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: locale
            )
    }

    private static func collapseWhitespace(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

enum DuplicateConfidence: String, CaseIterable, Sendable {
    case exact
    case strong
    case possible
    case notDuplicate = "not_duplicate"
}

enum DuplicateRuleCode: String, Sendable {
    case validISBNExact = "valid_isbn_exact"
    case normalizedTitleExact = "normalized_title_exact"
    case normalizedAuthorExact = "normalized_author_exact"
    case originalTitleExact = "original_title_exact"
    case titleTokenOverlap = "title_token_overlap"
    case publisherExact = "publisher_exact"
    case publicationYearNear = "publication_year_near"
    case conflictingValidISBN = "conflicting_valid_isbn"
    case editionOrTranslationHint = "edition_or_translation_hint"
}

struct DuplicateEvidence: Equatable, Sendable {
    let rule: DuplicateRuleCode
    let message: String
    let weight: Int
}

struct DuplicateProbe: Equatable, Sendable {
    let id: UUID?
    let title: String
    let originalTitle: String?
    let author: String
    let isbn: String?
    let publisher: String?
    let publicationYear: Int?

    init(id: UUID? = nil, draft: BookDraft) {
        self.id = id
        title = draft.title
        originalTitle = draft.originalTitle
        author = draft.author
        isbn = draft.isbn
        publisher = draft.publisher
        publicationYear = draft.publicationDate?.year
    }

    init(book: Book) {
        id = book.id
        title = book.title
        originalTitle = book.originalTitle
        author = book.author
        isbn = book.isbn
        publisher = book.publisher
        publicationYear = book.publicationDate?.year
    }
}

struct DuplicateCandidate: Identifiable, Equatable, Sendable {
    let existingBook: Book
    let incomingBookID: UUID?
    let confidence: DuplicateConfidence
    let evidence: [DuplicateEvidence]
    let score: Int
    let uncertainty: String

    var id: UUID { existingBook.id }
}

struct DuplicateCandidateSearchResult: Equatable, Sendable {
    static let possibleLookupLimit = 250

    let candidates: [DuplicateCandidate]
    let possibleLookupWasTruncated: Bool
}

enum DuplicateRules {
    static let possibleThreshold = 6
    static let titleOverlapThreshold = 0.6
    static let titleOverlapWeight = 4
    static let authorWeight = 3
    static let originalTitleWeight = 3
    static let publisherWeight = 1
    static let publicationYearWeight = 1
    static let conflictingISBNPenalty = -4
    static let editionOrTranslationHintWeight = 2
}

enum DuplicateDetectionEngine {
    static func evaluate(
        _ incoming: DuplicateProbe,
        against existing: Book
    ) -> DuplicateCandidate {
        let existingProbe = DuplicateProbe(book: existing)
        let incomingISBN = DuplicateISBNNormalizer.validate(incoming.isbn).validIdentifier
        let existingISBN = DuplicateISBNNormalizer.validate(existingProbe.isbn).validIdentifier

        if let incomingISBN, incomingISBN == existingISBN {
            return DuplicateCandidate(
                existingBook: existing,
                incomingBookID: incoming.id,
                confidence: .exact,
                evidence: [
                    DuplicateEvidence(
                        rule: .validISBNExact,
                        message: "两条记录具有完全一致且校验有效的 ISBN。",
                        weight: 100
                    )
                ],
                score: 100,
                uncertainty: "ISBN 一致仍不能自动判断用户是否希望保留独立版本或译本。"
            )
        }

        let incomingTitle = DuplicateTextNormalizer.titleKey(incoming.title)
        let existingTitle = DuplicateTextNormalizer.titleKey(existingProbe.title)
        let incomingAuthor = DuplicateTextNormalizer.authorKey(incoming.author)
        let existingAuthor = DuplicateTextNormalizer.authorKey(existingProbe.author)
        let hasConflictingISBN = incomingISBN != nil && existingISBN != nil && incomingISBN != existingISBN
        let hasConflictingOriginalTitle = normalizedOptionalTitle(incoming.originalTitle)
            .flatMap { incomingOriginal in
                normalizedOptionalTitle(existingProbe.originalTitle).map { incomingOriginal != $0 }
            } ?? false

        if incomingTitle == existingTitle,
           incomingAuthor == existingAuthor,
           !hasConflictingISBN,
           !hasConflictingOriginalTitle
        {
            return DuplicateCandidate(
                existingBook: existing,
                incomingBookID: incoming.id,
                confidence: .strong,
                evidence: [
                    DuplicateEvidence(
                        rule: .normalizedTitleExact,
                        message: "规范化书名完全一致。",
                        weight: 4
                    ),
                    DuplicateEvidence(
                        rule: .normalizedAuthorExact,
                        message: "规范化作者文本完全一致，且作者顺序保持不变。",
                        weight: 3
                    )
                ],
                score: 7,
                uncertainty: "规则未发现明确版本或译本冲突，但仍需要用户确认。"
            )
        }

        if incomingTitle == existingTitle,
           incomingAuthor == existingAuthor,
           hasConflictingISBN
        {
            return DuplicateCandidate(
                existingBook: existing,
                incomingBookID: incoming.id,
                confidence: .possible,
                evidence: [
                    DuplicateEvidence(
                        rule: .normalizedTitleExact,
                        message: "规范化书名完全一致。",
                        weight: DuplicateRules.titleOverlapWeight
                    ),
                    DuplicateEvidence(
                        rule: .normalizedAuthorExact,
                        message: "规范化作者文本完全一致。",
                        weight: DuplicateRules.authorWeight
                    ),
                    DuplicateEvidence(
                        rule: .conflictingValidISBN,
                        message: "两条记录具有不同的有效 ISBN，可能是不同版本或译本。",
                        weight: DuplicateRules.conflictingISBNPenalty
                    )
                ],
                score: DuplicateRules.titleOverlapWeight
                    + DuplicateRules.authorWeight
                    + DuplicateRules.conflictingISBNPenalty,
                uncertainty: "书名与作者一致，但有效 ISBN 不同；只能作为可能候选，不能自动合并。"
            )
        }

        if incomingAuthor == existingAuthor,
           looksLikeDifferentSeriesInstallment(incomingTitle, existingTitle)
        {
            return DuplicateCandidate(
                existingBook: existing,
                incomingBookID: incoming.id,
                confidence: .notDuplicate,
                evidence: [],
                score: 0,
                uncertainty: "标题仅在卷次标记上不同，按独立系列作品处理。"
            )
        }

        if DuplicateTextNormalizer.baseTitleKey(incoming.title)
            == DuplicateTextNormalizer.baseTitleKey(existingProbe.title),
            incomingAuthor == existingAuthor,
            incomingTitle != existingTitle
        {
            var evidence = [
                DuplicateEvidence(
                    rule: .normalizedAuthorExact,
                    message: "规范化作者文本一致。",
                    weight: DuplicateRules.authorWeight
                ),
                DuplicateEvidence(
                    rule: .editionOrTranslationHint,
                    message: "基础书名一致但副标题不同，可能是独立版本或译本。",
                    weight: DuplicateRules.editionOrTranslationHintWeight
                )
            ]
            if hasConflictingISBN {
                evidence.append(
                    DuplicateEvidence(
                        rule: .conflictingValidISBN,
                        message: "两条记录具有不同的有效 ISBN，不会自动判为强重复。",
                        weight: DuplicateRules.conflictingISBNPenalty
                    )
                )
            }
            return DuplicateCandidate(
                existingBook: existing,
                incomingBookID: incoming.id,
                confidence: .possible,
                evidence: evidence,
                score: evidence.reduce(0) { $0 + $1.weight },
                uncertainty: "标题包含版本差异；请人工确认是否应保留为独立记录。"
            )
        }

        var evidence: [DuplicateEvidence] = []
        var score = 0
        let titleOverlap = tokenOverlap(
            DuplicateTextNormalizer.titleTokens(incoming.title),
            DuplicateTextNormalizer.titleTokens(existingProbe.title)
        )
        if titleOverlap >= DuplicateRules.titleOverlapThreshold {
            score += DuplicateRules.titleOverlapWeight
            evidence.append(
                DuplicateEvidence(
                    rule: .titleTokenOverlap,
                    message: "规范化书名 token 重合度达到公开阈值 \(DuplicateRules.titleOverlapThreshold)。",
                    weight: DuplicateRules.titleOverlapWeight
                )
            )
        }
        if incomingAuthor == existingAuthor {
            score += DuplicateRules.authorWeight
            evidence.append(
                DuplicateEvidence(
                    rule: .normalizedAuthorExact,
                    message: "规范化作者文本一致。",
                    weight: DuplicateRules.authorWeight
                )
            )
        }
        if let incomingOriginal = normalizedOptionalTitle(incoming.originalTitle),
           let existingOriginal = normalizedOptionalTitle(existingProbe.originalTitle),
           incomingOriginal == existingOriginal
        {
            score += DuplicateRules.originalTitleWeight
            evidence.append(
                DuplicateEvidence(
                    rule: .originalTitleExact,
                    message: "规范化原书名一致。",
                    weight: DuplicateRules.originalTitleWeight
                )
            )
        }
        if let incomingPublisher = normalizedOptionalText(incoming.publisher),
           let existingPublisher = normalizedOptionalText(existingProbe.publisher),
           incomingPublisher == existingPublisher
        {
            score += DuplicateRules.publisherWeight
            evidence.append(
                DuplicateEvidence(
                    rule: .publisherExact,
                    message: "规范化出版社一致。",
                    weight: DuplicateRules.publisherWeight
                )
            )
        }
        if let incomingYear = incoming.publicationYear,
           let existingYear = existingProbe.publicationYear,
           abs(incomingYear - existingYear) <= 1
        {
            score += DuplicateRules.publicationYearWeight
            evidence.append(
                DuplicateEvidence(
                    rule: .publicationYearNear,
                    message: "出版年份相差不超过一年。",
                    weight: DuplicateRules.publicationYearWeight
                )
            )
        }
        if hasConflictingISBN {
            score += DuplicateRules.conflictingISBNPenalty
            evidence.append(
                DuplicateEvidence(
                    rule: .conflictingValidISBN,
                    message: "两条记录具有不同的有效 ISBN，可能是不同版本或译本。",
                    weight: DuplicateRules.conflictingISBNPenalty
                )
            )
        }
        if DuplicateTextNormalizer.baseTitleKey(incoming.title)
            == DuplicateTextNormalizer.baseTitleKey(existingProbe.title),
            incomingTitle != existingTitle
        {
            score += DuplicateRules.editionOrTranslationHintWeight
            evidence.append(
                DuplicateEvidence(
                    rule: .editionOrTranslationHint,
                    message: "副标题分隔符前的基础书名一致，可能是版本或译本说明。",
                    weight: DuplicateRules.editionOrTranslationHintWeight
                )
            )
        }

        let confidence: DuplicateConfidence = score >= DuplicateRules.possibleThreshold ? .possible : .notDuplicate
        return DuplicateCandidate(
            existingBook: existing,
            incomingBookID: incoming.id,
            confidence: confidence,
            evidence: evidence,
            score: score,
            uncertainty: confidence == .possible
                ? "这些信号只能说明可能相关，不能自动区分版本、译本、系列或相似书名。"
                : "现有确定性信号不足以标记为重复候选。"
        )
    }

    private static func normalizedOptionalTitle(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let normalized = DuplicateTextNormalizer.titleKey(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let normalized = value
            .precomposedStringWithCompatibilityMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private static func tokenOverlap(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else {
            return 0
        }
        let intersection = lhs.intersection(rhs).count
        let union = lhs.union(rhs).count
        return Double(intersection) / Double(union)
    }

    private static func looksLikeDifferentSeriesInstallment(_ lhs: String, _ rhs: String) -> Bool {
        let lhsWords = lhs.split(whereSeparator: \.isWhitespace).map(String.init)
        let rhsWords = rhs.split(whereSeparator: \.isWhitespace).map(String.init)
        guard lhsWords.count == rhsWords.count,
              lhsWords.count >= 3,
              lhsWords.dropLast() == rhsWords.dropLast(),
              lhsWords.last != rhsWords.last
        else {
            return false
        }
        let installmentMarkers: Set<String> = [
            "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
            "一", "二", "三", "四", "五", "六", "七", "八", "九", "十",
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"
        ]
        return installmentMarkers.contains(lhsWords.last ?? "")
            && installmentMarkers.contains(rhsWords.last ?? "")
    }
}

enum DuplicatePairDisposition: String, CaseIterable, Sendable {
    case notDuplicate = "not_duplicate"
    case separateEdition = "separate_edition"
    case separateTranslation = "separate_translation"
}

struct IgnoredDuplicatePair: Equatable, Sendable {
    let firstBookID: UUID
    let secondBookID: UUID
    let disposition: DuplicatePairDisposition
    let createdAt: Date
}
