import AppKit
import SwiftUI

struct QuotesListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var editorMode: EditorMode?
    @State private var quotePendingDelete: Quote?

    /// Live order while dragging; committed to the model once on drop.
    @State private var draftQuotes: [Quote] = []
    @State private var draggingID: UUID?
    @State private var draggedHeight: CGFloat = 0
    /// Finger Y minus the dragged row's top, captured at drag start (content Y).
    @State private var grabOffset: CGFloat = 0
    /// Finger location in the non-scrolling root space.
    @State private var fingerLocation: CGPoint = .zero
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @State private var longPressArmed = false
    @GestureState private var reorderGestureActive = false

    /// Scroll view frame in the root space (same space as the drag gesture).
    @State private var listFrame: CGRect = .zero
    @State private var scrollMetrics = ScrollMetrics()
    @State private var scrollProbe = ScrollClipProbeHandle()

    private let longPressDuration: Double = 0.12
    private let listTopPadding: CGFloat = 8
    private let listHorizontalPadding: CGFloat = 12
    private let autoScrollEdge: CGFloat = 72
    private let autoScrollMaxStep: CGFloat = 22
    private let rootSpace = "QuotesListRoot"

    var body: some View {
        Group {
            if model.quotes.isEmpty {
                ContentUnavailableView {
                    Label("No Quotes Yet", systemImage: "quote.bubble")
                } description: {
                    Text("Add quotes in QotD. They’ll show up on your Desktop Widget.")
                }
            } else {
                reorderableQuotes
            }
        }
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
        .onAppear {
            draftQuotes = model.quotes
        }
        .onChange(of: model.quotes) { _, quotes in
            guard draggingID == nil else { return }
            draftQuotes = quotes
        }
    }

    // MARK: - List + floating preview

    private var reorderableQuotes: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                // Non-lazy so the dragged row (which owns the gesture) is never torn down
                // when auto-scroll moves it off screen.
                VStack(spacing: 0) {
                    // Walks up to the backing NSScrollView for pixel-level clip scrolling.
                    ScrollClipProbe(handle: scrollProbe)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)

                    ForEach(Array(draftQuotes.enumerated()), id: \.element.id) { index, quote in
                        quoteBlock(quote, index: index)
                            .id(quote.id)
                    }
                }
                .padding(.horizontal, listHorizontalPadding)
                .padding(.top, listTopPadding)
                .padding(.bottom, listTopPadding + 72)
            }
            .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
                ScrollMetrics(
                    offsetY: geo.contentOffset.y,
                    insetTop: geo.contentInsets.top,
                    insetBottom: geo.contentInsets.bottom,
                    contentHeight: geo.contentSize.height,
                    containerHeight: geo.containerSize.height
                )
            } action: { _, metrics in
                scrollMetrics = metrics
            }
            .onGeometryChange(for: CGRect.self) { geo in
                geo.frame(in: .named(rootSpace))
            } action: { _, frame in
                listFrame = frame
            }
            .task(id: draggingID) {
                guard draggingID != nil else { return }
                scrollProbe.resolveIfNeeded()
                while !Task.isCancelled {
                    autoScrollTick()
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }

            if let draggingID, let quote = draftQuotes.first(where: { $0.id == draggingID }) {
                dragPreview(quote)
            }
        }
        .coordinateSpace(.named(rootSpace))
        .onChange(of: reorderGestureActive) { _, active in
            if !active { finishDrag() }
        }
    }

    private func dragPreview(_ quote: Quote) -> some View {
        let width = max(listFrame.width - listHorizontalPadding * 2, 0)
        return rowContent(quote)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .scaleEffect(1.015)
            .frame(width: width)
            .offset(
                x: listFrame.minX + listHorizontalPadding,
                y: fingerLocation.y - grabOffset
            )
            .allowsHitTesting(false)
            .transition(.identity)
    }

    // MARK: - Rows

    private func rowContent(_ quote: Quote) -> some View {
        QuoteRowView(quote: quote)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func quoteBlock(_ quote: Quote, index: Int) -> some View {
        let isDragging = draggingID == quote.id

        VStack(spacing: 0) {
            rowContent(quote)
                .opacity(isDragging ? 0 : 1)
                .background {
                    if isDragging {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                    }
                }

            if index < draftQuotes.count - 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(height: 1)
                    .padding(.horizontal, 10)
            }
        }
        .frame(height: isDragging ? draggedHeight : nil, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { geo in
            geo.size.height
        } action: { _, height in
            rowHeights[quote.id] = height
        }
        .gesture(reorderGesture(for: quote))
        .onTapGesture {
            guard draggingID == nil, !longPressArmed else { return }
            editorMode = .edit(quote)
        }
        .contextMenu {
            Button("Edit") {
                editorMode = .edit(quote)
            }
            Button("Set as Active") {
                model.setActiveQuote(quote)
            }
            Button(isPinnedQuote(quote) ? "Unpin" : "Pin") {
                model.pinQuote(quote)
            }
            Divider()
            Button("Delete", role: .destructive) {
                quotePendingDelete = quote
            }
        }
        .accessibilityHint("Press and hold to reorder")
    }

    // MARK: - Drag

    private func reorderGesture(for quote: Quote) -> some Gesture {
        LongPressGesture(minimumDuration: longPressDuration, maximumDistance: 8)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(rootSpace)))
            .updating($reorderGestureActive) { _, active, _ in
                active = true
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    longPressArmed = true
                case .second(true, let drag):
                    guard let drag else { return }
                    if draggingID == nil {
                        beginDrag(quote, at: drag.startLocation)
                    }
                    guard draggingID == quote.id else { return }
                    fingerLocation = drag.location
                    updateDraftOrder()
                default:
                    break
                }
            }
            .onEnded { _ in
                finishDrag()
            }
    }

    private func beginDrag(_ quote: Quote, at start: CGPoint) {
        guard let index = draftQuotes.firstIndex(where: { $0.id == quote.id }) else { return }
        draggedHeight = height(of: quote.id)
        // grabOffset is in root-space points (preview offset uses root Y, not content Y).
        let rowTopInRoot = listFrame.minY + (rowTop(at: index, in: draftQuotes.map(\.id)) - scrollMetrics.offsetY)
        grabOffset = start.y - rowTopInRoot
        fingerLocation = start
        longPressArmed = true
        scrollProbe.resolveIfNeeded()
        draggingID = quote.id
    }

    /// Root-space Y → scroll content Y. The finger and preview never scroll,
    /// so only this mapping uses the scroll offset.
    private func contentY(forRootY rootY: CGFloat) -> CGFloat {
        let offset = scrollProbe.contentOffsetY ?? scrollMetrics.offsetY
        return rootY - listFrame.minY + offset
    }

    private func height(of id: UUID) -> CGFloat {
        rowHeights[id] ?? 56
    }

    private func rowTop(at index: Int, in ids: [UUID]) -> CGFloat {
        ids.prefix(index).reduce(listTopPadding) { $0 + height(of: $1) }
    }

    /// Moves the dragged quote to the slot whose top is nearest the preview's top.
    private func updateDraftOrder() {
        guard
            let draggingID,
            let current = draftQuotes.firstIndex(where: { $0.id == draggingID })
        else { return }

        let previewTopContent = contentY(forRootY: fingerLocation.y - grabOffset)
        let others = draftQuotes.map(\.id).filter { $0 != draggingID }

        var best = 0
        var bestDistance = CGFloat.infinity
        var slotTop = listTopPadding
        for slot in 0...others.count {
            let distance = abs(previewTopContent - slotTop)
            if distance < bestDistance {
                bestDistance = distance
                best = slot
            }
            if slot < others.count {
                slotTop += height(of: others[slot])
            }
        }

        guard best != current else { return }
        withAnimation(.snappy(duration: 0.2)) {
            let item = draftQuotes.remove(at: current)
            draftQuotes.insert(item, at: best)
        }
    }

    /// Auto-scroll the list pane under a stationary finger. Safe with the floating
    /// preview because the preview is not inside the scrolling content.
    private func autoScrollTick() {
        guard draggingID != nil, listFrame.height > 1 else { return }

        // Edge bands are relative to the Quotes list frame in root space — not the monitor.
        let y = fingerLocation.y
        let top = listFrame.minY
        let bottom = listFrame.maxY

        var step: CGFloat = 0
        if y < top + autoScrollEdge {
            let depth = min((top + autoScrollEdge - y) / autoScrollEdge, 1)
            step = -max(autoScrollMaxStep * depth * depth, 2)
        } else if y > bottom - autoScrollEdge {
            let depth = min((y - (bottom - autoScrollEdge)) / autoScrollEdge, 1)
            step = max(autoScrollMaxStep * depth * depth, 2)
        }
        guard step != 0 else { return }

        scrollProbe.resolveIfNeeded()
        let scrolled: Bool
        if scrollProbe.scrollBy(step) {
            scrolled = true
            if let offset = scrollProbe.contentOffsetY {
                scrollMetrics.offsetY = offset
            }
        } else {
            // Fallback if NSScrollView isn't found yet: nudge via scroll metrics only
            // (no visual scroll) — prefer resolving the probe.
            scrolled = false
        }

        if scrolled {
            updateDraftOrder()
        }
    }

    private func finishDrag() {
        let didDrag = draggingID != nil
        let ordered = draftQuotes
        draggingID = nil
        draggedHeight = 0
        grabOffset = 0
        longPressArmed = false

        if didDrag {
            model.reorderQuotes(ordered)
            draftQuotes = model.quotes
        }
    }

    private func isPinnedQuote(_ quote: Quote) -> Bool {
        model.store.playback.isPinned && model.store.playback.currentQuoteId == quote.id
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

// MARK: - AppKit clip scrolling

@MainActor
private final class ScrollClipProbeHandle {
    weak var anchorView: NSView?
    weak var scrollView: NSScrollView?

    var contentOffsetY: CGFloat? {
        scrollView?.contentView.bounds.origin.y
    }

    func resolveIfNeeded() {
        if scrollView != nil { return }
        var node: NSView? = anchorView
        while let current = node {
            if let scroll = current as? NSScrollView {
                scrollView = scroll
                return
            }
            node = current.superview
        }
    }

    @discardableResult
    func scrollBy(_ deltaY: CGFloat) -> Bool {
        resolveIfNeeded()
        guard let scrollView else { return false }
        let clip = scrollView.contentView
        let documentHeight = scrollView.documentView?.bounds.height ?? clip.bounds.height
        let maxY = max(0, documentHeight - clip.bounds.height)
        var origin = clip.bounds.origin
        let next = min(max(0, origin.y + deltaY), maxY)
        guard abs(next - origin.y) > 0.5 else { return false }
        origin.y = next
        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
        return true
    }
}

private final class ScrollClipProbeNSView: NSView {
    var handle: ScrollClipProbeHandle?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        handle?.anchorView = self
        DispatchQueue.main.async { [weak self] in
            self?.handle?.anchorView = self
            self?.handle?.resolveIfNeeded()
        }
    }

    override func layout() {
        super.layout()
        handle?.anchorView = self
        handle?.resolveIfNeeded()
    }
}

private struct ScrollClipProbe: NSViewRepresentable {
    let handle: ScrollClipProbeHandle

    func makeNSView(context: Context) -> ScrollClipProbeNSView {
        let view = ScrollClipProbeNSView()
        view.handle = handle
        handle.anchorView = view
        return view
    }

    func updateNSView(_ nsView: ScrollClipProbeNSView, context: Context) {
        nsView.handle = handle
        handle.anchorView = nsView
        handle.resolveIfNeeded()
    }
}

// MARK: - Reorder helpers

private struct ScrollMetrics: Equatable {
    var offsetY: CGFloat = 0
    var insetTop: CGFloat = 0
    var insetBottom: CGFloat = 0
    var contentHeight: CGFloat = 0
    var containerHeight: CGFloat = 0
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
