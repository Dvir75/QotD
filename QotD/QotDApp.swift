import SwiftUI
import AppKit

@main
struct QotDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("QotD", id: "main") {
            ContentView()
                .environment(appDelegate.model)
                .frame(minWidth: 560, minHeight: 420)
                .background(MainWindowTracker())
                .background(WindowFocusBridge())
                .onOpenURL { appDelegate.handleIncomingURL($0) }
        }
        .defaultSize(width: 720, height: 520)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Quote") {
                    NotificationCenter.default.post(name: .qotdAddQuote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

/// Recreates / focuses the main window (Dock, Quotes, Settings).
private struct WindowFocusBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                MainWindowSupport.openWindowAction = { openWindow(id: "main") }
            }
            .onReceive(NotificationCenter.default.publisher(for: .qotdFocusMainWindow)) { _ in
                openWindow(id: "main")
            }
    }
}
