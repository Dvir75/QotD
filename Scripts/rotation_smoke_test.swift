#!/usr/bin/env swift
import Foundation

// Minimal inline copies of rotation types for a fast smoke test without XCTest.

struct Quote: Identifiable, Equatable {
    var id: UUID
    var text: String
    var author: String
    var sortOrder: Int
}

enum RotationMode { case sequential, randomNoRepeat }

struct AppSettings {
    var rotationMode: RotationMode
    var intervalSeconds: TimeInterval
}

struct PlaybackState {
    var currentQuoteId: UUID?
    var nextChangeDate: Date?
    var shownQuoteIds: [UUID]
}

struct Store {
    var quotes: [Quote]
    var settings: AppSettings
    var playback: PlaybackState
    var sortedQuotes: [Quote] { quotes.sorted { $0.sortOrder < $1.sortOrder } }
}

enum Engine {
    static func reconcile(_ store: Store, now: Date) -> Store {
        var store = store
        let quotes = store.sortedQuotes
        guard !quotes.isEmpty else {
            store.playback = PlaybackState(currentQuoteId: nil, nextChangeDate: nil, shownQuoteIds: [])
            return store
        }
        let validIDs = Set(quotes.map(\.id))
        store.playback.shownQuoteIds = store.playback.shownQuoteIds.filter { validIDs.contains($0) }
        if let current = store.playback.currentQuoteId, !validIDs.contains(current) {
            store.playback.currentQuoteId = nil
            store.playback.nextChangeDate = nil
        }
        if store.playback.currentQuoteId == nil {
            let chosen = quotes[0]
            store.playback.currentQuoteId = chosen.id
            store.playback.shownQuoteIds = [chosen.id]
            store.playback.nextChangeDate = now.addingTimeInterval(store.settings.intervalSeconds)
            return store
        }
        if let next = store.playback.nextChangeDate, now >= next {
            return advance(store, quotes: quotes, now: now)
        }
        return store
    }

    static func advance(_ store: Store, quotes: [Quote], now: Date) -> Store {
        var store = store
        let currentID = store.playback.currentQuoteId
        let next: Quote
        switch store.settings.rotationMode {
        case .sequential:
            if let currentID, let index = quotes.firstIndex(where: { $0.id == currentID }) {
                next = quotes[(index + 1) % quotes.count]
            } else {
                next = quotes[0]
            }
            store.playback.shownQuoteIds = []
        case .randomNoRepeat:
            var shown = Set(store.playback.shownQuoteIds)
            if shown.count >= quotes.count { shown = [] }
            let pool = quotes.filter { !shown.contains($0.id) }
            let preferred = pool.filter { $0.id != currentID }
            next = (preferred.isEmpty ? pool : preferred).randomElement()!
            shown.insert(next.id)
            store.playback.shownQuoteIds = Array(shown)
        }
        store.playback.currentQuoteId = next.id
        store.playback.nextChangeDate = now.addingTimeInterval(store.settings.intervalSeconds)
        return store
    }
}

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    print("OK: \(message)")
}

let a = Quote(id: UUID(), text: "A", author: "Unknown", sortOrder: 0)
let b = Quote(id: UUID(), text: "B", author: "Unknown", sortOrder: 1)
let c = Quote(id: UUID(), text: "C", author: "Unknown", sortOrder: 2)
let now = Date()

var store = Store(
    quotes: [a, b, c],
    settings: AppSettings(rotationMode: .sequential, intervalSeconds: 60),
    playback: PlaybackState(currentQuoteId: nil, nextChangeDate: nil, shownQuoteIds: [])
)

store = Engine.reconcile(store, now: now)
expect(store.playback.currentQuoteId == a.id, "initial sequential picks first quote")
expect(store.playback.nextChangeDate == now.addingTimeInterval(60), "schedules next change")

// Within interval — stable
let mid = Engine.reconcile(store, now: now.addingTimeInterval(30))
expect(mid.playback.currentQuoteId == a.id, "quote stable before interval ends")

// After interval — advance
store = Engine.reconcile(store, now: now.addingTimeInterval(60))
expect(store.playback.currentQuoteId == b.id, "sequential advances to second quote")

store = Engine.reconcile(store, now: now.addingTimeInterval(120))
expect(store.playback.currentQuoteId == c.id, "sequential advances to third quote")

store = Engine.reconcile(store, now: now.addingTimeInterval(180))
expect(store.playback.currentQuoteId == a.id, "sequential wraps to first quote")

// Empty clears playback
var empty = store
empty.quotes = []
empty = Engine.reconcile(empty, now: now.addingTimeInterval(200))
expect(empty.playback.currentQuoteId == nil, "empty list clears playback")

// Random no-repeat covers all before repeating
var randomStore = Store(
    quotes: [a, b, c],
    settings: AppSettings(rotationMode: .randomNoRepeat, intervalSeconds: 10),
    playback: PlaybackState(currentQuoteId: nil, nextChangeDate: nil, shownQuoteIds: [])
)
randomStore = Engine.reconcile(randomStore, now: now)
var seen = Set<UUID>()
seen.insert(randomStore.playback.currentQuoteId!)
for step in 1...2 {
    randomStore = Engine.reconcile(randomStore, now: now.addingTimeInterval(TimeInterval(step * 10)))
    seen.insert(randomStore.playback.currentQuoteId!)
}
expect(seen.count == 3, "random no-repeat shows all three before repeat cycle")

print("All rotation smoke tests passed.")
