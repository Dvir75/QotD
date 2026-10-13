import SwiftUI

enum UserGuideStore {
    static let hasSeenKey = "qotd.hasSeenUserGuide"

    static var hasSeen: Bool {
        UserDefaults.standard.bool(forKey: hasSeenKey)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenKey)
    }
}

struct UserGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0

    private let steps: [(title: String, body: String)] = [
        (
            "Welcome to QotD",
            "QotD shows your personal quotes on a Desktop Widget, rotating on a schedule. This window is where you add and manage them."
        ),
        (
            "Add the widget",
            "Right-click the Desktop, choose Edit Widgets, then add QotD. Without the widget, quotes stay in the app only."
        ),
        (
            "Add quotes",
            "Use + to add a quote; click one to edit. When adding, paste into an empty Quote field to split quote and author automatically. Cleanup and Auto-capitalize are in Settings."
        ),
        (
            "Menu bar",
            "While QotD is running, the menu bar icon offers Pin, Next, Quotes, Settings, and Quit. Clicking the widget opens this menu. Dock, Quotes, or Settings open this window. Closing the window keeps the menu bar; Quit removes it."
        ),
        (
            "Quotes list",
            "Press and hold a quote to reorder. Right-click for Set as Active, Pin or Unpin, and Delete."
        ),
        (
            "Settings",
            "Choose Sequential or Random rotation, set how often quotes change, and adjust paste options."
        ),
    ]

    private var isFirst: Bool { stepIndex == 0 }
    private var isLast: Bool { stepIndex == steps.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(steps[stepIndex].title)
                        .font(.title2.weight(.semibold))
                        .id(stepIndex)

                    Text(steps[stepIndex].body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("body-\(stepIndex)")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(.snappy(duration: 0.2), value: stepIndex)

                pageControls
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .navigationTitle("User Guide")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isLast {
                        Button("Got it") {
                            finish()
                        }
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Close") {
                            finish()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 300, idealHeight: 340)
        .onAppear {
            stepIndex = 0
        }
    }

    private func finish() {
        UserGuideStore.markSeen()
        dismiss()
    }

    private var pageControls: some View {
        HStack(spacing: 20) {
            arrowButton(
                systemName: "chevron.left",
                help: "Previous",
                disabled: isFirst
            ) {
                stepIndex -= 1
            }

            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == stepIndex ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(
                            width: index == stepIndex ? 8 : 6,
                            height: index == stepIndex ? 8 : 6
                        )
                        .animation(.snappy(duration: 0.2), value: stepIndex)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(stepIndex + 1) of \(steps.count)")

            arrowButton(
                systemName: "chevron.right",
                help: "Next",
                disabled: isLast,
                shortcut: isLast ? nil : .defaultAction
            ) {
                stepIndex += 1
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func arrowButton(
        systemName: String,
        help: String,
        disabled: Bool,
        shortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(disabled)
        .help(help)
        .modifier(OptionalKeyboardShortcut(shortcut: shortcut))
    }
}

private struct OptionalKeyboardShortcut: ViewModifier {
    let shortcut: KeyboardShortcut?

    func body(content: Content) -> some View {
        if let shortcut {
            content.keyboardShortcut(shortcut)
        } else {
            content
        }
    }
}
