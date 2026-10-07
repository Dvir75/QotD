import SwiftUI

struct QuotesListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var editorMode: EditorMode?
    @State private var quotePendingDelete: Quote?

    var body: some View {
        Group {
            if model.quotes.isEmpty {
                ContentUnavailableView {
                    Label("No Quotes Yet", systemImage: "quote.bubble")
                } description: {
                    Text("Add quotes in QotD. They’ll show up on your Desktop Widget.")
                }
            } else {
                List {
                    ForEach(model.quotes) { quote in
                        Button {
                            editorMode = .edit(quote)
                        } label: {
                            QuoteRowView(quote: quote)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit") {
                                editorMode = .edit(quote)
                            }
                            Button("Delete", role: .destructive) {
                                quotePendingDelete = quote
                            }
                        }
                    }
                    .onDelete(perform: model.deleteQuotes)
                    .onMove(perform: model.moveQuotes)
                }
            }
        }
        // Same as Settings: title only, no toolbar / no hidden toolbar buttons
        // (those make the Quotes header highlight on hover).
        .navigationTitle("Quotes")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .overlay(alignment: .bottomTrailing) {
            addQuoteButton
                .padding(20)
        }
        .onReceive(NotificationCenter.default.publisher(for: .qotdAddQuote)) { _ in
            editorMode = .add
        }
        .sheet(item: $editorMode) { mode in
            QuoteEditorView(mode: mode)
        }
        .confirmationDialog(
            "Delete this quote?",
            isPresented: Binding(
                get: { quotePendingDelete != nil },
                set: { if !$0 { quotePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let quote = quotePendingDelete {
                    model.deleteQuote(quote)
                }
                quotePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                quotePendingDelete = nil
            }
        }
    }

    private var addQuoteButton: some View {
        Button {
            editorMode = .add
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(addQuoteButtonFill, in: Circle())
        }
        .buttonStyle(.plain)
        .help("Add Quote")
        .accessibilityLabel("Add Quote")
        .shadow(color: .black.opacity(controlActiveState == .inactive ? 0.12 : 0.25), radius: 6, y: 2)
    }

    private var addQuoteButtonFill: Color {
        switch controlActiveState {
        case .inactive:
            Color(nsColor: .systemGray)
        default:
            Color.accentColor
        }
    }
}

struct QuoteRowView: View {
    let quote: Quote

    var body: some View {
        // Keep the row LTR so leading/trailing mean left/right.
        // Hebrew script still renders RTL inside the Text; we only pin edges.
        VStack(alignment: .leading, spacing: 4) {
            Text(quote.text)
                .font(QuoteFont.quote(isHebrew: quote.isHebrew))
                .foregroundStyle(.primary)
                .multilineTextAlignment(quote.isHebrew ? .trailing : .leading)
                .frame(
                    maxWidth: .infinity,
                    alignment: quote.isHebrew ? .trailing : .leading
                )
            QuoteAttributionLabel(author: quote.displayAuthor, isHebrew: quote.isHebrew)
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.vertical, 4)
    }
}

enum EditorMode: Identifiable {
    case add
    case edit(Quote)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let quote): quote.id.uuidString
        }
    }
}
