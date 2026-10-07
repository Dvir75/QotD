import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let revealWindow: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let pinItem = NSMenuItem(
        title: "Pin",
        action: #selector(togglePin),
        keyEquivalent: ""
    )
    private let nextItem = NSMenuItem(
        title: "Next",
        action: #selector(skipToNext),
        keyEquivalent: ""
    )

    init(model: AppModel, revealWindow: @escaping () -> Void) {
        self.model = model
        self.revealWindow = revealWindow
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "quote.opening",
                accessibilityDescription: "QotD"
            )
            button.image?.isTemplate = true
        }
        statusItem.isVisible = true

        let quotesItem = NSMenuItem(
            title: "Quotes",
            action: #selector(openQuotes),
            keyEquivalent: ""
        )
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        let updatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        let quitItem = NSMenuItem(
            title: "Quit QotD",
            action: #selector(quit),
            keyEquivalent: "q"
        )

        pinItem.target = self
        nextItem.target = self
        quotesItem.target = self
        settingsItem.target = self
        updatesItem.target = self
        quitItem.target = self

        Self.applyTrailingSymbol("pin", to: pinItem)
        Self.applyTrailingSymbol("forward.end", to: nextItem)
        Self.applyTrailingSymbol("quote.bubble", to: quotesItem)
        Self.applyTrailingSymbol("gearshape", to: settingsItem)
        Self.applyTrailingSymbol("arrow.down.circle", to: updatesItem)
        Self.applyTrailingSymbol("rectangle.portrait.and.arrow.right", to: quitItem)

        menu.delegate = self
        menu.items = [
            pinItem,
            nextItem,
            .separator(),
            quotesItem,
            settingsItem,
            updatesItem,
            .separator(),
            quitItem,
        ]
        statusItem.menu = menu
    }

    func pop() {
        statusItem.isVisible = true
        statusItem.button?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        popWhenStatusItemIsOnScreen(attempts: 0)
    }

    /// Cold launch: the extra has no screen frame yet, so `performClick` parks
    /// the menu at the display origin (top-left). Wait until the button is laid out.
    private func popWhenStatusItemIsOnScreen(attempts: Int) {
        let maxAttempts = 40
        let delay: TimeInterval = 0.05

        if let button = statusItem.button,
           let window = button.window,
           button.bounds.width > 1,
           button.bounds.height > 1 {
            let screenRect = window.convertToScreen(button.convert(button.bounds, to: nil))
            // Status extras sit on the right of the menu bar. Origin (0,0) means
            // AppKit has not assigned a slot yet.
            if screenRect.width > 1, screenRect.minX > 8 {
                button.performClick(nil)
                return
            }
        }

        guard attempts < maxAttempts else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.popWhenStatusItemIsOnScreen(attempts: attempts + 1)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pinItem.state = model.store.playback.isPinned ? .on : .off
        let hasQuotes = !model.quotes.isEmpty
        pinItem.isEnabled = hasQuotes
        nextItem.isEnabled = hasQuotes
    }

    @objc private func togglePin() {
        model.togglePin()
    }

    @objc private func skipToNext() {
        model.skipToNext()
    }

    @objc private func openQuotes() {
        model.sidebar = .quotes
        NotificationCenter.default.post(name: .qotdOpenQuotes, object: nil)
        revealWindow()
    }

    @objc private func openSettings() {
        model.sidebar = .settings
        NotificationCenter.default.post(name: .qotdOpenSettings, object: nil)
        revealWindow()
    }

    @objc private func checkForUpdates() {
        UpdateController.shared.checkForUpdates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private static func applyTrailingSymbol(_ name: String, to item: NSMenuItem) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return
        }
        image.isTemplate = true
        item.image = image
        if #available(macOS 27.0, *) {
            item.preferredImageVisibility = .visible
        }
    }
}
