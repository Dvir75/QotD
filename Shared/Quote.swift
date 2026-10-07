import Foundation

struct Quote: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var text: String
    var author: String
    var sortOrder: Int

    static let unknownAuthor = "Unknown"
    static let unknownAuthorHebrew = "לא ידוע"

    init(id: UUID = UUID(), text: String, author: String = "", sortOrder: Int) {
        self.id = id
        self.text = text
        self.author = Self.normalizedAuthor(author)
        self.sortOrder = sortOrder
    }

    static func normalizedAuthor(_ author: String) -> String {
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? unknownAuthor : trimmed
    }

    /// Hebrew block (letters, points, marks): U+0590...U+05FF.
    static func containsHebrew(_ string: String) -> Bool {
        string.unicodeScalars.contains { scalar in
            (0x0590...0x05FF).contains(scalar.value)
        }
    }

    /// Direction and script follow quote text only; author follows.
    static func isHebrewQuote(_ text: String) -> Bool {
        containsHebrew(text)
    }

    /// Maps stored `Unknown` to Hebrew fallback when the quote text is Hebrew.
    static func displayAuthor(text: String, author: String) -> String {
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUnknown = trimmed.isEmpty || trimmed == unknownAuthor
        if isUnknown, isHebrewQuote(text) {
            return unknownAuthorHebrew
        }
        return isUnknown ? unknownAuthor : trimmed
    }

    /// For RTL, keep logical `Author —` and render under LTR so bidi does not pull the dash left of the name.
    static func attribution(author: String, isRTL: Bool) -> String {
        isRTL ? "\(author) —" : "— \(author)"
    }

    var isHebrew: Bool { Self.isHebrewQuote(text) }

    var displayAuthor: String {
        Self.displayAuthor(text: text, author: author)
    }

    var attribution: String {
        Self.attribution(author: displayAuthor, isRTL: isHebrew)
    }
}
