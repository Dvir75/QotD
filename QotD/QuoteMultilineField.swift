import AppKit
import SwiftUI

/// Multiline quote field. SwiftUI `TextEditor` ignores alignment and always shows a scroller;
/// vertical `TextField` rejects Hebrew after one character.
struct QuoteMultilineField: NSViewRepresentable {
    @Binding var text: String
    var isRTL: Bool
    var isFocused: Bool
    var onFocus: () -> Void
    var onTab: () -> Void
    var onBackTab: () -> Void
    /// Return `true` to consume the paste (clipboard string already applied by caller).
    var onPaste: ((String) -> Bool)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        // No visible scroller — it reserves a trailing gutter and misaligns with Author.
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = .init()
        scrollView.scrollerInsets = .init()

        let textView = TabbingTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        // Match SwiftUI TextField: no extra text-container inset.
        textView.textContainerInset = .init(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.onTab = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onTab()
        }
        textView.onBackTab = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onBackTab()
        }
        textView.onPasteString = { [weak coordinator = context.coordinator] pasted in
            coordinator?.parent.onPaste?(pasted) ?? false
        }
        applyDirection(isRTL, to: textView)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? TabbingTextView else { return }

        textView.onTab = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onTab()
        }
        textView.onBackTab = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onBackTab()
        }
        textView.onPasteString = { [weak coordinator = context.coordinator] pasted in
            coordinator?.parent.onPaste?(pasted) ?? false
        }
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .init(width: 0, height: 0)

        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
        applyDirection(isRTL, to: textView)

        DispatchQueue.main.async {
            guard isFocused, let window = scrollView.window else { return }
            if window.firstResponder !== textView {
                window.makeFirstResponder(textView)
            }
        }
    }

    private func applyDirection(_ isRTL: Bool, to textView: NSTextView) {
        let alignment: NSTextAlignment = isRTL ? .right : .left
        let writing: NSWritingDirection = isRTL ? .rightToLeft : .leftToRight
        if textView.alignment != alignment {
            textView.alignment = alignment
        }
        if textView.baseWritingDirection != writing {
            textView.baseWritingDirection = writing
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuoteMultilineField
        weak var textView: TabbingTextView?

        init(parent: QuoteMultilineField) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocus()
        }
    }
}

final class TabbingTextView: NSTextView {
    var onTab: (() -> Void)?
    var onBackTab: (() -> Void)?
    /// Return `true` if the paste was handled externally.
    var onPasteString: ((String) -> Bool)?

    override func insertTab(_ sender: Any?) {
        onTab?()
    }

    override func insertBacktab(_ sender: Any?) {
        onBackTab?()
    }

    override func paste(_ sender: Any?) {
        if let onPasteString,
           let pasted = NSPasteboard.general.string(forType: .string),
           onPasteString(pasted) {
            return
        }
        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        paste(sender)
    }
}
