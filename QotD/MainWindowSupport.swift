import AppKit
import SwiftUI

/// Keeps a handle on the main window and turns the close button into hide
/// (`orderOut`) so Dock / Quotes / Settings can bring it back.
enum MainWindowSupport {
    private(set) static var window: NSWindow?
    static var openWindowAction: (() -> Void)?

    static func register(_ window: NSWindow) {
        guard isAppWindow(window) else { return }
        Self.window = window
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        if let close = window.standardWindowButton(.closeButton) {
            close.target = CloseProxy.shared
            close.action = #selector(CloseProxy.hide)
        }
    }

    static func hide() {
        for candidate in appWindows() {
            register(candidate)
            candidate.orderOut(nil)
        }
        window?.orderOut(nil)
    }

    @discardableResult
    static func reveal() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if present(window) {
            return true
        }
        for candidate in appWindows() {
            register(candidate)
            if present(candidate) {
                return true
            }
        }
        return false
    }

    /// Last resort when SwiftUI never instantiated `Window(id: "main")`
    /// (widget URL launch).
    static func materializeIfNeeded(model: AppModel) {
        if reveal() { return }
        openWindowAction?()
        DispatchQueue.main.async {
            if Self.window?.isVisible == true { return }
            Self.materializeHostingWindow(model: model)
        }
    }

    private static func materializeHostingWindow(model: AppModel) {
        if reveal() { return }
        let root = ContentView()
            .environment(model)
            .frame(minWidth: 560, minHeight: 420)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "QotD"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 520))
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.center()
        register(window)
        present(window)
    }

    @discardableResult
    private static func present(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    static func appWindows() -> [NSWindow] {
        NSApp.windows.filter(isAppWindow)
    }

    static func isAppWindow(_ window: NSWindow) -> Bool {
        !(window is NSPanel)
            && !isStatusBarWindow(window)
            && window.styleMask.contains(.titled)
            && window.styleMask.contains(.closable)
            && window.canBecomeMain
    }

    private static func isStatusBarWindow(_ window: NSWindow) -> Bool {
        let name = NSStringFromClass(type(of: window))
        return name.contains("StatusBar")
            || (window.frame.height <= 32 && !window.styleMask.contains(.titled))
    }
}

private final class CloseProxy: NSObject {
    static let shared = CloseProxy()

    @objc func hide() {
        MainWindowSupport.hide()
    }
}

struct MainWindowTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                MainWindowSupport.register(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                MainWindowSupport.register(window)
            }
        }
    }
}
