import Foundation

struct PlaybackState: Codable, Equatable {
    var currentQuoteId: UUID?
    var nextChangeDate: Date?
    var shownQuoteIds: [UUID]
    /// When true, rotation is frozen on `currentQuoteId` until unpinned or skipped.
    var isPinned: Bool

    static let empty = PlaybackState(
        currentQuoteId: nil,
        nextChangeDate: nil,
        shownQuoteIds: [],
        isPinned: false
    )

    enum CodingKeys: String, CodingKey {
        case currentQuoteId
        case nextChangeDate
        case shownQuoteIds
        case isPinned
    }

    init(
        currentQuoteId: UUID?,
        nextChangeDate: Date?,
        shownQuoteIds: [UUID],
        isPinned: Bool = false
    ) {
        self.currentQuoteId = currentQuoteId
        self.nextChangeDate = nextChangeDate
        self.shownQuoteIds = shownQuoteIds
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentQuoteId = try container.decodeIfPresent(UUID.self, forKey: .currentQuoteId)
        nextChangeDate = try container.decodeIfPresent(Date.self, forKey: .nextChangeDate)
        shownQuoteIds = try container.decodeIfPresent([UUID].self, forKey: .shownQuoteIds) ?? []
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(currentQuoteId, forKey: .currentQuoteId)
        try container.encodeIfPresent(nextChangeDate, forKey: .nextChangeDate)
        try container.encode(shownQuoteIds, forKey: .shownQuoteIds)
        try container.encode(isPinned, forKey: .isPinned)
    }
}
