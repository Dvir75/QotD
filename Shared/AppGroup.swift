import Foundation

enum AppGroup {
    /// macOS App Group format is `<TeamID>.<name>` — NOT `group.…`
    /// See: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups
    /// Team-ID–prefixed groups do not need Developer portal registration or profile allowlisting.
    static let identifier = "55FZJ4852Q.com.dviramitai.QotD"
    static let storeFileName = "qotd-store.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var storeURL: URL? {
        containerURL?.appendingPathComponent(storeFileName)
    }
}
