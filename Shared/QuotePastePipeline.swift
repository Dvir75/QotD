import Foundation

/// First-paste pipeline for new quotes: split → optional cleanup → optional auto-cap.
enum QuotePastePipeline {
    struct Options: Equatable {
        var cleanup: Bool
        var autoCapitalize: Bool
    }

    struct Result: Equatable {
        var text: String
        var author: String
    }

    static func process(_ raw: String, options: Options) -> Result {
        var parts = split(raw)
        if options.cleanup {
            parts.text = cleanupQuoteText(parts.text)
            parts.author = cleanupAuthor(parts.author)
        }
        if options.autoCapitalize {
            parts.text = capitalizeFirstLetter(parts.text)
            parts.author = titleCaseWords(parts.author)
        }
        return parts
    }

    // MARK: - Split

    static func split(_ raw: String) -> Result {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Result(text: "", author: "")
        }

        if let multi = splitMultiline(trimmed) {
            return multi
        }
        if let quoted = splitQuotedSingleLine(trimmed) {
            return quoted
        }
        if let unquoted = splitUnquotedSingleLine(trimmed) {
            return unquoted
        }
        return Result(text: trimmed, author: "")
    }

    private static func splitMultiline(_ text: String) -> Result? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return nil }
        let last = lines[lines.count - 1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let author = attributionOnlyLine(last) else { return nil }
        let quoteLines = lines.dropLast()
        let quote = quoteLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty else { return nil }
        return Result(text: quote, author: author)
    }

    /// Returns author text if the line is only an attribution (dash/`by`/`מאת`/…).
    private static func attributionOnlyLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let rest = stripLeadingAuthorPrefix(trimmed), rest != trimmed, !rest.isEmpty {
            // Entire line was prefix + name (or prefix-only junk).
            return rest
        }

        // Dash/`~`/`•` with optional space then name (already covered by strip), or `by Name`.
        return nil
    }

    private static func splitQuotedSingleLine(_ text: String) -> Result? {
        for pair in quotePairs {
            guard text.count >= 2, text.first == pair.open else { continue }
            // Find closing quote before a separator; use last matching close that still leaves a separator+author.
            var searchStart = text.index(after: text.startIndex)
            while searchStart < text.endIndex {
                guard let closeIdx = text[searchStart...].firstIndex(of: pair.close) else { break }
                let afterClose = text.index(after: closeIdx)
                let remainder = String(text[afterClose...])
                if let author = authorAfterSeparator(remainder) {
                    let inner = String(text[text.index(after: text.startIndex)..<closeIdx])
                    let quote = inner.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !quote.isEmpty, !author.isEmpty {
                        return Result(text: quote, author: author)
                    }
                }
                searchStart = afterClose
            }
        }
        return nil
    }

    private static func splitUnquotedSingleLine(_ text: String) -> Result? {
        // Prefer spaced dash separators; take the last match.
        let dashPatterns = [" — ", " – ", " - ", " ― "]
        var bestDash: (range: Range<String.Index>, author: String)?
        for pattern in dashPatterns {
            if let range = text.range(of: pattern, options: .backwards) {
                let author = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let quote = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !quote.isEmpty, !author.isEmpty {
                    if bestDash == nil || range.lowerBound > bestDash!.range.lowerBound {
                        bestDash = (range, author)
                    }
                }
            }
        }
        // Symbol separators with spaces
        for pattern in [" ~ ", " • "] {
            if let range = text.range(of: pattern, options: .backwards) {
                let author = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let quote = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !quote.isEmpty, !author.isEmpty {
                    if bestDash == nil || range.lowerBound > bestDash!.range.lowerBound {
                        bestDash = (range, author)
                    }
                }
            }
        }

        var bestWord: (range: Range<String.Index>, author: String)?
        for marker in wordAttributionMarkers {
            if let found = lastWordAttribution(in: text, marker: marker) {
                if bestWord == nil || found.range.lowerBound > bestWord!.range.lowerBound {
                    bestWord = found
                }
            }
        }

        // Pick the rightmost split among dash and word forms.
        switch (bestDash, bestWord) {
        case let (d?, w?):
            if d.range.lowerBound >= w.range.lowerBound {
                return Result(text: String(text[..<d.range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines), author: d.author)
            }
            return Result(text: String(text[..<w.range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines), author: w.author)
        case let (d?, nil):
            return Result(text: String(text[..<d.range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines), author: d.author)
        case let (nil, w?):
            return Result(text: String(text[..<w.range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines), author: w.author)
        case (nil, nil):
            return nil
        }
    }

    private static func authorAfterSeparator(_ remainder: String) -> String? {
        let trimmed = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Optional separator then author.
        if let stripped = stripLeadingAuthorPrefix(trimmed), !stripped.isEmpty {
            return stripped
        }
        // `by Author` / `מאת Author` without also counting as "prefix-only" failure
        for marker in wordAttributionMarkers {
            if let rest = stripMarkerPrefix(trimmed, marker: marker), !rest.isEmpty {
                return rest
            }
        }
        return nil
    }

    private static func lastWordAttribution(
        in text: String,
        marker: String
    ) -> (range: Range<String.Index>, author: String)? {
        let options: String.CompareOptions = marker.unicodeScalars.allSatisfy(\.isASCII)
            ? [.backwards, .caseInsensitive]
            : [.backwards]
        // Prefer " marker " so mid-word matches are avoided; fall back to " marker" at end.
        let needles = [" \(marker) ", " \(marker)"]
        var found: Range<String.Index>?
        for needle in needles {
            if let range = text.range(of: needle, options: options) {
                if found == nil || range.lowerBound > found!.lowerBound {
                    found = range
                }
            }
        }
        guard let range = found else { return nil }
        let author = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let quote = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        // Trailing attribution only — reject huge "author" tails (likely mid-sentence `by`).
        guard !quote.isEmpty, !author.isEmpty, author.count <= 80 else { return nil }
        return (range, author)
    }

    // MARK: - Cleanup

    static func cleanupQuoteText(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = result.first, quoteMarkCharacters.contains(first) {
            result.removeFirst()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while let last = result.last, quoteMarkCharacters.contains(last) {
            result.removeLast()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    static func cleanupAuthor(_ author: String) -> String {
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let stripped = stripLeadingAuthorPrefix(trimmed) {
            return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    /// Strips at most one leading author prefix. Returns nil if nothing matched.
    static func stripLeadingAuthorPrefix(_ author: String) -> String? {
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in authorPrefixesLongestFirst {
            if let rest = stripMarkerPrefix(trimmed, marker: prefix) {
                return rest
            }
        }
        // Symbol dashes / bullets (including glued and repeated ---)
        if let rest = stripLeadingDashSymbols(trimmed) {
            return rest
        }
        return nil
    }

    private static func stripMarkerPrefix(_ text: String, marker: String) -> String? {
        let isASCII = marker.unicodeScalars.allSatisfy { $0.isASCII }
        if isASCII {
            guard text.count >= marker.count else { return nil }
            let end = text.index(text.startIndex, offsetBy: marker.count)
            let head = text[text.startIndex..<end]
            guard head.compare(marker, options: .caseInsensitive) == .orderedSame else { return nil }
            var rest = String(text[end...])
            // Word markers should not tear into a longer word (`bypass`)
            if marker.last?.isLetter == true || marker.last == ":" {
                if marker.hasSuffix(":") {
                    rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
                    return rest
                }
                if rest.isEmpty { return "" }
                guard rest.first?.isWhitespace == true else { return nil }
                return rest.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            guard text.hasPrefix(marker) else { return nil }
            let rest = String(text.dropFirst(marker.count))
            if marker.last?.isLetter == true || marker.last == ":" {
                if marker.hasSuffix(":") {
                    return rest.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if rest.isEmpty { return "" }
                guard rest.first?.isWhitespace == true else { return nil }
            }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func stripLeadingDashSymbols(_ text: String) -> String? {
        var index = text.startIndex
        var saw = false
        while index < text.endIndex {
            let ch = text[index]
            if dashOrBulletCharacters.contains(ch) {
                saw = true
                index = text.index(after: index)
                continue
            }
            if saw, ch.isWhitespace {
                index = text.index(after: index)
                continue
            }
            break
        }
        guard saw else { return nil }
        return String(text[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Auto-cap

    static func capitalizeFirstLetter(_ text: String) -> String {
        guard let idx = text.firstIndex(where: \.isLetter) else { return text }
        let ch = text[idx]
        let upper = String(ch).uppercased()
        guard String(ch) != upper else { return text }
        return String(text[..<idx]) + upper + String(text[text.index(after: idx)...])
    }

    static func titleCaseWords(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.split(separator: " ", omittingEmptySubsequences: false)
            .map { word -> String in
                let s = String(word)
                guard let idx = s.firstIndex(where: \.isLetter) else { return s }
                let first = String(s[idx]).uppercased()
                let restStart = s.index(after: idx)
                let rest = restStart < s.endIndex ? s[restStart...].lowercased() : ""
                return String(s[..<idx]) + first + rest
            }
            .joined(separator: " ")
    }

    // MARK: - Tables

    private struct QuotePair {
        let open: Character
        let close: Character
    }

    private static let quotePairs: [QuotePair] = [
        QuotePair(open: "\"", close: "\""),
        QuotePair(open: "\u{201C}", close: "\u{201D}"), // “ ”
        QuotePair(open: "«", close: "»"),
        QuotePair(open: "\u{05F4}", close: "\u{05F4}"), // ״ ״
        QuotePair(open: "'", close: "'"),
        QuotePair(open: "\u{2018}", close: "\u{2019}"), // ‘ ’
    ]

    private static let quoteMarkCharacters: Set<Character> = [
        "\"", "\u{201C}", "\u{201D}", "«", "»", "\u{05F4}", "'", "\u{2018}", "\u{2019}",
    ]

    private static let dashOrBulletCharacters: Set<Character> = [
        "-", "\u{2013}", "\u{2014}", "\u{2015}", "~", "\u{2022}",
    ]

    /// Word / phrase markers used for split (with surrounding spaces).
    private static let wordAttributionMarkers: [String] = [
        "according to",
        "as said by",
        "quoted from",
        "ציטוט מאת",
        "ציטוט מ",
        "על פי",
        "כפי שאמר",
        "כדברי",
        "מאת",
        "מתוך",
        "לפי",
        "by",
        "from",
        "via",
        "per",
    ]

    /// Longest-first for one-shot author cleanup (includes labeled forms).
    private static let authorPrefixesLongestFirst: [String] = [
        "according to",
        "as said by",
        "quoted from",
        "ציטוט מאת",
        "ציטוט מ",
        "על פי",
        "כפי שאמר",
        "כדברי",
        "source:",
        "author:",
        "מקור:",
        "מחבר:",
        "מאת",
        "מתוך",
        "לפי",
        "by",
        "from",
        "via",
        "per",
    ]
}
