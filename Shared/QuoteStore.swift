import Foundation

enum QuoteStore {
    private static let defaultsKey = "qotd.store.data"
    static let textKey = "qotd.current.text"
    static let authorKey = "qotd.current.author"
    static let pinnedKey = "qotd.current.pinned"
    static let countKey = "qotd.quote.count"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    /// Shared App Group defaults. Never fall back to `.standard` — that is per-process and breaks sharing.
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    static var hasSharedStore: Bool {
        guard let defaults = sharedDefaults else { return false }
        if defaults.data(forKey: defaultsKey) != nil { return true }
        if defaults.string(forKey: textKey) != nil { return true }
        if let url = AppGroup.storeURL, FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        return false
    }

    static var diagnosticsDescription: String {
        let container = AppGroup.containerURL?.path ?? "nil"
        let fileExists = AppGroup.storeURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let defaults = sharedDefaults
        let defaultsOK = defaults?.data(forKey: defaultsKey) != nil
        let preview = defaults?.string(forKey: textKey) ?? "(none)"
        let suiteOK = defaults != nil
        return "group=\(AppGroup.identifier)\nsuite=\(suiteOK)\ncontainer=\(container)\nfile=\(fileExists) defaults=\(defaultsOK)\npreview=\(preview)"
    }

    /// Fast path for the widget — read only.
    static func currentQuotePreview() -> (text: String, author: String, isPinned: Bool, quoteCount: Int)? {
        guard let defaults = sharedDefaults,
              let text = defaults.string(forKey: textKey), !text.isEmpty else {
            return nil
        }
        let author = defaults.string(forKey: authorKey) ?? Quote.unknownAuthor
        let isPinned = defaults.bool(forKey: pinnedKey)
        let quoteCount = defaults.integer(forKey: countKey)
        return (text, author, isPinned, quoteCount)
    }

    /// Read-only load for the widget extension (never writes).
    static func loadReadOnly() -> QotDStoreData {
        if let defaults = sharedDefaults,
           let data = defaults.data(forKey: defaultsKey),
           let decoded = try? decoder.decode(QotDStoreData.self, from: data) {
            return decoded
        }
        if let url = AppGroup.storeURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode(QotDStoreData.self, from: data) {
            return decoded
        }
        return .empty
    }

    static func load() -> QotDStoreData {
        let loaded = loadReadOnly()
        if !loaded.quotes.isEmpty {
            return loaded
        }
        // Migrate legacy Application Support → App Group (app process only).
        if let legacy = loadLegacyApplicationSupport(), !legacy.quotes.isEmpty {
            _ = save(legacy)
            return legacy
        }
        return .empty
    }

    @discardableResult
    static func save(_ store: QotDStoreData) -> Bool {
        guard let data = try? encoder.encode(store) else { return false }
        guard let defaults = sharedDefaults else { return false }

        defaults.set(data, forKey: defaultsKey)

        if let quote = RotationEngine.currentQuote(in: store) ?? store.sortedQuotes.first {
            defaults.set(quote.text, forKey: textKey)
            defaults.set(quote.author, forKey: authorKey)
            defaults.set(store.playback.isPinned, forKey: pinnedKey)
        } else {
            defaults.removeObject(forKey: textKey)
            defaults.removeObject(forKey: authorKey)
            defaults.removeObject(forKey: pinnedKey)
        }
        defaults.set(store.quotes.count, forKey: countKey)
        defaults.synchronize()

        var fileOK = false
        if let url = AppGroup.storeURL {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: [.atomic])
                fileOK = true
            } catch {
                fileOK = false
            }
        }

        return defaults.data(forKey: defaultsKey) != nil || fileOK
    }

    private static func loadLegacyApplicationSupport() -> QotDStoreData? {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else { return nil }
        let url = URL(fileURLWithPath: String(cString: dir), isDirectory: true)
            .appendingPathComponent("Library/Application Support/QotD/qotd-store.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode(QotDStoreData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
