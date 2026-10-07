import Foundation

enum QotDWidgetKind {
    static let current = "QotDWidgetV19"
}

enum QotDURL {
    static let scheme = "qotd"
    static let menuHost = "menu"
    static let openHost = "open"

    static var menu: URL {
        URL(string: "\(scheme)://\(menuHost)")!
    }

    static var openApp: URL {
        URL(string: "\(scheme)://\(openHost)")!
    }

    static func isMenuAction(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == menuHost
    }
}

extension Notification.Name {
    static let qotdFocusMainWindow = Notification.Name("qotd.focusMainWindow")
    static let qotdAddQuote = Notification.Name("qotd.addQuote")
    static let qotdOpenQuotes = Notification.Name("qotd.openQuotes")
    static let qotdOpenSettings = Notification.Name("qotd.openSettings")
}
