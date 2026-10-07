import SwiftUI

struct QuoteEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let mode: EditorMode

    @State private var text: String = ""
    @State private var author: String = ""
    @State private var didSmartPaste = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case quote
        case author
    }

    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }

    private var navigationTitle: String {
        switch mode {
        case .add: "New Quote"
        case .edit: "Edit Quote"
        }
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isHebrew: Bool {
        Quote.isHebrewQuote(text)
    }

    private var authorPrompt: String {
        isHebrew ? Quote.unknownAuthorHebrew : Quote.unknownAuthor
    }

    private var textAlignment: TextAlignment {
        isHebrew ? .trailing : .leading
    }

    /// Slightly brighter than the window chrome so the field reads as an input.
    private var fieldFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.04)
    }

    private var pasteCleanupBinding: Binding<Bool> {
        Binding(
            get: { model.store.settings.pasteCleanupEnabled },
            set: { model.setPasteCleanupEnabled($0) }
        )
    }

    private var pasteAutoCapitalizeBinding: Binding<Bool> {
        Binding(
            get: { model.store.settings.pasteAutoCapitalizeEnabled },
            set: { model.setPasteAutoCapitalizeEnabled($0) }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                quoteRow
                authorRow
                if isAdding {
                    pasteOptionToggles
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .environment(\.layoutDirection, .leftToRight)
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 420, minHeight: isAdding ? 320 : 280)
        .onAppear {
            switch mode {
            case .add:
                text = ""
                author = ""
                didSmartPaste = false
            case .edit(let quote):
                text = quote.text
                author = quote.author == Quote.unknownAuthor ? "" : quote.author
            }
            focusedField = .quote
        }
    }

    private let labelWidth: CGFloat = 56
    private let fieldPadding: CGFloat = 8

    private var quoteRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Quote")
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
                .padding(.top, fieldPadding)

            QuoteMultilineField(
                text: $text,
                isRTL: isHebrew,
                isFocused: focusedField == .quote,
                onFocus: { focusedField = .quote },
                onTab: { focusedField = .author },
                onBackTab: { },
                onPaste: handleSmartPaste
            )
                .padding(fieldPadding)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .background(fieldFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .focused($focusedField, equals: .quote)
        }
    }

    private var authorRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Author")
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)

            TextField("", text: $author, prompt: Text(authorPrompt))
                .textFieldStyle(.plain)
                .font(.body)
                .multilineTextAlignment(textAlignment)
                .focused($focusedField, equals: .author)
                .onSubmit { save() }
                .padding(fieldPadding)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: isHebrew ? .trailing : .leading)
                .background(fieldFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .onKeyPress(.tab) {
                    focusedField = .quote
                    return .handled
                }
        }
    }

    private var pasteOptionToggles: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.clear.frame(width: labelWidth)
            VStack(spacing: 8) {
                pasteToggleRow("Cleanup", isOn: pasteCleanupBinding)
                pasteToggleRow("Auto-capitalize", isOn: pasteAutoCapitalizeBinding)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pasteToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    /// First paste into empty Quote+Author while adding — split / cleanup / auto-cap once.
    private func handleSmartPaste(_ pasted: String) -> Bool {
        guard isAdding, !didSmartPaste else { return false }
        let quoteEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let authorEmpty = author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard quoteEmpty, authorEmpty else { return false }

        let result = QuotePastePipeline.process(
            pasted,
            options: .init(
                cleanup: model.store.settings.pasteCleanupEnabled,
                autoCapitalize: model.store.settings.pasteAutoCapitalizeEnabled
            )
        )
        text = result.text
        author = result.author
        didSmartPaste = true
        if !result.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            focusedField = .author
        }
        return true
    }

    private func save() {
        switch mode {
        case .add:
            model.addQuote(text: text, author: author)
        case .edit(let quote):
            model.updateQuote(quote, text: text, author: author)
        }
        dismiss()
    }
}
