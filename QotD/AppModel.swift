import Foundation
import Observation
import WidgetKit

enum AppSidebar: Hashable {
    case quotes
    case settings
}

@Observable
final class AppModel {
    var store: QotDStoreData = .empty
    var lastSaveSucceeded: Bool = true
    var sidebar: AppSidebar = .quotes

    private var rotationTimer: Timer?

    var quotes: [Quote] {
        store.sortedQuotes
    }

    init() {
        reloadFromDisk()
        startRotationTimer()
    }

    func reloadFromDisk() {
        var loaded = QuoteStore.load()
        loaded = RotationEngine.reconcile(loaded)
        store = loaded
        lastSaveSucceeded = QuoteStore.save(store)
    }

    func persist(reloadWidget: Bool = true) {
        store = RotationEngine.reconcile(store)
        lastSaveSucceeded = QuoteStore.save(store)
        if reloadWidget {
            WidgetCenter.shared.reloadTimelines(ofKind: QotDWidgetKind.current)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func startRotationTimer() {
        rotationTimer?.invalidate()
        // Poll often enough to honor short debug intervals (e.g. 5s).
        let poll = min(30, max(1, store.settings.intervalSeconds / 2))
        let timer = Timer(timeInterval: poll, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tickRotation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        rotationTimer = timer
    }

    private func tickRotation() {
        // Prefer disk playback so pin/next from the widget win while the app is open.
        var merged = store
        merged.playback = QuoteStore.loadReadOnly().playback
        let updated = RotationEngine.reconcile(merged)
        guard updated != store else { return }
        store = updated
        lastSaveSucceeded = QuoteStore.save(store)
        WidgetCenter.shared.reloadTimelines(ofKind: QotDWidgetKind.current)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Quotes

    func addQuote(text: String, author: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (store.quotes.map(\.sortOrder).max() ?? -1) + 1
        let quote = Quote(text: trimmed, author: author, sortOrder: nextOrder)
        store.quotes.append(quote)
        persist()
    }

    func updateQuote(_ quote: Quote, text: String, author: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = store.quotes.firstIndex(where: { $0.id == quote.id }) else { return }
        store.quotes[index].text = trimmed
        store.quotes[index].author = Quote.normalizedAuthor(author)
        persist()
    }

    func deleteQuotes(at offsets: IndexSet) {
        let sorted = quotes
        let ids = offsets.map { sorted[$0].id }
        store.quotes.removeAll { ids.contains($0.id) }
        reindexSortOrders()
        persist()
    }

    func deleteQuote(_ quote: Quote) {
        store.quotes.removeAll { $0.id == quote.id }
        reindexSortOrders()
        persist()
    }

    func moveQuotes(from source: IndexSet, to destination: Int) {
        var ordered = quotes
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, quote) in ordered.enumerated() {
            if let storeIndex = store.quotes.firstIndex(where: { $0.id == quote.id }) {
                store.quotes[storeIndex].sortOrder = index
            }
        }
        persist()
    }

    private func reindexSortOrders() {
        for (index, quote) in quotes.enumerated() {
            if let storeIndex = store.quotes.firstIndex(where: { $0.id == quote.id }) {
                store.quotes[storeIndex].sortOrder = index
            }
        }
    }

    // MARK: - Settings

    func setRotationMode(_ mode: RotationMode) {
        store.settings.rotationMode = mode
        store.playback.shownQuoteIds = []
        persist()
    }

    func setIntervalSeconds(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
        store.settings.intervalSeconds = seconds
        store = RotationEngine.rescheduleCurrent(store)
        lastSaveSucceeded = QuoteStore.save(store)
        startRotationTimer()
        WidgetCenter.shared.reloadTimelines(ofKind: QotDWidgetKind.current)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setPasteCleanupEnabled(_ enabled: Bool) {
        store.settings.pasteCleanupEnabled = enabled
        persist(reloadWidget: false)
    }

    func setPasteAutoCapitalizeEnabled(_ enabled: Bool) {
        store.settings.pasteAutoCapitalizeEnabled = enabled
        persist(reloadWidget: false)
    }

    func togglePin() {
        store = RotationEngine.togglePin(store)
        lastSaveSucceeded = QuoteStore.save(store)
        WidgetCenter.shared.reloadTimelines(ofKind: QotDWidgetKind.current)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func skipToNext() {
        store = RotationEngine.advanceToNext(store)
        lastSaveSucceeded = QuoteStore.save(store)
        WidgetCenter.shared.reloadTimelines(ofKind: QotDWidgetKind.current)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
