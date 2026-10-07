import WidgetKit
import SwiftUI

struct QuoteEntry: TimelineEntry {
    let date: Date
    let text: String
    let author: String
}

/// Keep getTimeline extremely cheap. Never write. Never decode JSON here —
/// chronod leaves the desktop widget on gray redacted bars if the provider
/// is slow or the extension dies during the first timeline fetch after add.
struct QotDTimelineProvider: TimelineProvider {
    init() {
        QuoteFont.registerIfNeeded()
    }

    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: .now, text: "Quote of the Day", author: "QotD")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func currentEntry() -> QuoteEntry {
        if let preview = QuoteStore.currentQuotePreview() {
            return QuoteEntry(date: .now, text: preview.text, author: preview.author)
        }
        return QuoteEntry(date: .now, text: "Add quotes in QotD", author: "QotD")
    }
}

struct QotDWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuoteEntry

    var body: some View {
        GeometryReader { geo in
            let metrics = Self.metrics(for: family, size: geo.size)
            let isHebrew = Quote.isHebrewQuote(entry.text)
            let author = Quote.displayAuthor(text: entry.text, author: entry.author)

            ZStack(alignment: .topLeading) {
                Text(verbatim: entry.text)
                    .font(QuoteFont.quote(metrics.quoteSize, isHebrew: isHebrew))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(isHebrew ? .trailing : .leading)
                    .lineSpacing(metrics.lineSpacing)
                    .minimumScaleFactor(0.35)
                    .lineLimit(metrics.lineLimit)
                    .frame(
                        width: geo.size.width - metrics.padding * 2,
                        height: geo.size.height - metrics.padding * 2 - metrics.footerClearance,
                        alignment: isHebrew ? .topTrailing : .topLeading
                    )
                    .padding(metrics.padding)

                QuoteAttributionLabel(
                    author: author,
                    isHebrew: isHebrew,
                    size: metrics.authorSize
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(metrics.padding)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(QotDURL.menu)
        .unredacted()
    }

    private struct Metrics {
        var quoteSize: CGFloat
        var authorSize: CGFloat
        var padding: CGFloat
        var lineSpacing: CGFloat
        var lineLimit: Int
        var footerClearance: CGFloat
    }

    private static func metrics(for family: WidgetFamily, size: CGSize) -> Metrics {
        let shortest = max(1, min(size.width, size.height))
        let quoteFromGeo = shortest * 0.16
        let authorFromGeo = shortest * 0.065
        let footerClearance = max(18, authorFromGeo + 10)

        switch family {
        case .systemSmall:
            return Metrics(
                quoteSize: max(20, quoteFromGeo),
                authorSize: max(11, authorFromGeo),
                padding: 12,
                lineSpacing: 2,
                lineLimit: 8,
                footerClearance: footerClearance
            )
        case .systemMedium:
            return Metrics(
                quoteSize: max(24, quoteFromGeo),
                authorSize: max(12, authorFromGeo),
                padding: 14,
                lineSpacing: 3,
                lineLimit: 7,
                footerClearance: footerClearance
            )
        case .systemLarge:
            return Metrics(
                quoteSize: max(30, quoteFromGeo),
                authorSize: max(14, authorFromGeo),
                padding: 18,
                lineSpacing: 4,
                lineLimit: 14,
                footerClearance: footerClearance
            )
        case .systemExtraLarge:
            return Metrics(
                quoteSize: max(36, quoteFromGeo),
                authorSize: max(16, authorFromGeo),
                padding: 22,
                lineSpacing: 5,
                lineLimit: 18,
                footerClearance: footerClearance
            )
        default:
            return Metrics(
                quoteSize: max(24, quoteFromGeo),
                authorSize: max(12, authorFromGeo),
                padding: 14,
                lineSpacing: 3,
                lineLimit: 10,
                footerClearance: footerClearance
            )
        }
    }
}

struct QotDWidget: Widget {
    let kind = QotDWidgetKind.current

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QotDTimelineProvider()) { entry in
            QotDWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quote of the Day")
        .description("Shows your quotes on a schedule.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
