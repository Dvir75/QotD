import Foundation

struct QotDStoreData: Codable, Equatable {
    var quotes: [Quote]
    var settings: AppSettings
    var playback: PlaybackState

    static let empty = QotDStoreData(
        quotes: [],
        settings: .default,
        playback: .empty
    )

    var sortedQuotes: [Quote] {
        quotes.sorted { $0.sortOrder < $1.sortOrder }
    }
}
