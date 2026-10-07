import Foundation

enum RotationEngine {
    /// Ensures playback points at a valid quote and advances when the interval has elapsed.
    static func reconcile(_ store: QotDStoreData, now: Date = .now) -> QotDStoreData {
        var store = store
        let quotes = store.sortedQuotes

        guard !quotes.isEmpty else {
            store.playback = .empty
            return store
        }

        // Drop stale IDs if quotes were deleted.
        let validIDs = Set(quotes.map(\.id))
        store.playback.shownQuoteIds = store.playback.shownQuoteIds.filter { validIDs.contains($0) }
        if let current = store.playback.currentQuoteId, !validIDs.contains(current) {
            store.playback.currentQuoteId = nil
            store.playback.nextChangeDate = nil
            store.playback.isPinned = false
        }

        if store.playback.currentQuoteId == nil {
            store = selectInitialQuote(store, quotes: quotes, now: now)
            return store
        }

        // Pinned: hold current quote; do not schedule or advance.
        if store.playback.isPinned {
            store.playback.nextChangeDate = nil
            return store
        }

        if let next = store.playback.nextChangeDate, now >= next {
            store = advance(store, quotes: quotes, now: now)
        } else if store.playback.nextChangeDate == nil {
            store.playback.nextChangeDate = now.addingTimeInterval(store.settings.intervalSeconds)
        }

        return store
    }

    /// Forces a new interval window using the current quote (e.g. after settings change).
    static func rescheduleCurrent(_ store: QotDStoreData, now: Date = .now) -> QotDStoreData {
        var store = store
        guard store.playback.currentQuoteId != nil else {
            return reconcile(store, now: now)
        }
        if store.playback.isPinned {
            store.playback.nextChangeDate = nil
            return store
        }
        store.playback.nextChangeDate = now.addingTimeInterval(store.settings.intervalSeconds)
        return store
    }

    /// Toggle pin on the currently displayed quote.
    static func togglePin(_ store: QotDStoreData, now: Date = .now) -> QotDStoreData {
        var store = store
        guard store.playback.currentQuoteId != nil, !store.sortedQuotes.isEmpty else {
            return store
        }
        store.playback.isPinned.toggle()
        if store.playback.isPinned {
            store.playback.nextChangeDate = nil
        } else {
            store.playback.nextChangeDate = now.addingTimeInterval(store.settings.intervalSeconds)
        }
        return store
    }

    /// Skip to the next quote immediately (clears pin).
    static func advanceToNext(_ store: QotDStoreData, now: Date = .now) -> QotDStoreData {
        var store = store
        store.playback.isPinned = false
        let quotes = store.sortedQuotes
        guard !quotes.isEmpty else {
            store.playback = .empty
            return store
        }
        if store.playback.currentQuoteId == nil {
            return selectInitialQuote(store, quotes: quotes, now: now)
        }
        return advance(store, quotes: quotes, now: now)
    }

    private static func selectInitialQuote(
        _ store: QotDStoreData,
        quotes: [Quote],
        now: Date
    ) -> QotDStoreData {
        var store = store
        let chosen: Quote
        switch store.settings.rotationMode {
        case .sequential:
            chosen = quotes[0]
            store.playback.shownQuoteIds = [chosen.id]
        case .randomNoRepeat:
            chosen = quotes.randomElement()!
            store.playback.shownQuoteIds = [chosen.id]
        }
        store.playback.currentQuoteId = chosen.id
        store.playback.isPinned = false
        store.playback.nextChangeDate = now.addingTimeInterval(store.settings.intervalSeconds)
        return store
    }

    private static func advance(
        _ store: QotDStoreData,
        quotes: [Quote],
        now: Date
    ) -> QotDStoreData {
        var store = store
        let currentID = store.playback.currentQuoteId

        let next: Quote
        switch store.settings.rotationMode {
        case .sequential:
            next = nextSequential(after: currentID, in: quotes)
            store.playback.shownQuoteIds = []
        case .randomNoRepeat:
            var shown = Set(store.playback.shownQuoteIds)
            if shown.count >= quotes.count {
                shown = []
            }
            let pool = quotes.filter { !shown.contains($0.id) }
            // Prefer not immediately repeating current when pool had been reset.
            let preferred = pool.filter { $0.id != currentID }
            next = (preferred.isEmpty ? pool : preferred).randomElement() ?? quotes.randomElement()!
            shown.insert(next.id)
            store.playback.shownQuoteIds = Array(shown)
        }

        store.playback.currentQuoteId = next.id
        store.playback.isPinned = false
        store.playback.nextChangeDate = now.addingTimeInterval(store.settings.intervalSeconds)
        return store
    }

    private static func nextSequential(after currentID: UUID?, in quotes: [Quote]) -> Quote {
        guard let currentID,
              let index = quotes.firstIndex(where: { $0.id == currentID }) else {
            return quotes[0]
        }
        let nextIndex = (index + 1) % quotes.count
        return quotes[nextIndex]
    }

    static func currentQuote(in store: QotDStoreData) -> Quote? {
        guard let id = store.playback.currentQuoteId else { return nil }
        return store.quotes.first { $0.id == id }
    }
}
