import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var menuBar: MenuBarController?
    private var pendingMenuPop = false
    private var didFinishLaunching = false
    private var receivedMenuURL = false
    private var menuURLAt = Date.distantPast
    /// Widget taps keep this false so stray SwiftUI windows can be hidden.
    /// Quotes / Settings / Dock set it true so those windows stay up.
    private var wantsMainWindow = false
    private var hideAfterWidgetGeneration = 0

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        if let url = urlFromCurrentAppleEvent(), QotDURL.isMenuAction(url) {
            noteMenuURL()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        QuoteFont.registerIfNeeded()
        WidgetExtensionRelauncher.relaunchIfBuildChanged()
        model.persist()
        menuBar = MenuBarController(model: model) { [weak self] in
            self?.focusMainWindow(openIfNeeded: true)
        }
        didFinishLaunching = true

        if pendingMenuPop || receivedMenuURL {
            popExtraWithoutOpeningWindow()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.receivedMenuURL else { return }
            self.focusMainWindow(openIfNeeded: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if isRecentMenuURLActivation && !wantsMainWindow {
            return false
        }
        if !flag {
            focusMainWindow(openIfNeeded: true)
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handleIncomingURL)
    }

    func application(
        _ application: NSApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        if let url = userActivity.webpageURL {
            handleIncomingURL(url)
            return QotDURL.isMenuAction(url)
        }
        let info = userActivity.userInfo ?? [:]
        let looksLikeWidget = info.keys.contains { key in
            String(describing: key).localizedCaseInsensitiveContains("widget")
        }
        if looksLikeWidget {
            noteMenuURL()
            if didFinishLaunching {
                popExtraWithoutOpeningWindow()
            } else {
                pendingMenuPop = true
            }
            return true
        }
        return false
    }

    func handleIncomingURL(_ url: URL) {
        guard QotDURL.isMenuAction(url) else { return }
        noteMenuURL()
        if didFinishLaunching {
            popExtraWithoutOpeningWindow()
        } else {
            pendingMenuPop = true
        }
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard
            let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: string)
        else { return }
        handleIncomingURL(url)
    }

    @discardableResult
    func focusMainWindow(openIfNeeded: Bool) -> Bool {
        wantsMainWindow = true
        hideAfterWidgetGeneration += 1
        if MainWindowSupport.reveal() {
            return true
        }
        guard openIfNeeded else { return false }
        MainWindowSupport.openWindowAction?()
        NotificationCenter.default.post(name: .qotdFocusMainWindow, object: nil)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsMainWindow else { return }
            if MainWindowSupport.reveal() { return }
            MainWindowSupport.materializeIfNeeded(model: self.model)
        }
        return false
    }

    private var isRecentMenuURLActivation: Bool {
        receivedMenuURL && Date().timeIntervalSince(menuURLAt) < 2
    }

    private func noteMenuURL() {
        receivedMenuURL = true
        menuURLAt = Date()
        pendingMenuPop = true
        wantsMainWindow = false
    }

    private func popExtraWithoutOpeningWindow() {
        wantsMainWindow = false
        let windowWasVisible = MainWindowSupport.appWindows().contains { $0.isVisible }
        menuBar?.pop()
        if !windowWasVisible {
            scheduleHideAfterWidgetActivation()
        }
    }

    private func scheduleHideAfterWidgetActivation() {
        hideAfterWidgetGeneration += 1
        hideMainWindowAfterActivation(attempts: 20, generation: hideAfterWidgetGeneration)
    }

    private func hideMainWindowAfterActivation(attempts: Int, generation: Int) {
        guard generation == hideAfterWidgetGeneration, !wantsMainWindow else { return }
        MainWindowSupport.hide()
        guard attempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.hideMainWindowAfterActivation(attempts: attempts - 1, generation: generation)
        }
    }

    private func urlFromCurrentAppleEvent() -> URL? {
        let event = NSAppleEventManager.shared().currentAppleEvent
        guard
            event?.eventClass == AEEventClass(kInternetEventClass),
            event?.eventID == AEEventID(kAEGetURL),
            let string = event?.paramDescriptor(forKeyword: keyDirectObject)?.stringValue
        else { return nil }
        return URL(string: string)
    }
}
