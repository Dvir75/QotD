import SwiftUI
import CoreText
import Foundation

enum QuoteFont {
    static let latinQuotePostScript = "CormorantGaramond-Regular"
    static let latinAuthorPostScript = "CormorantGaramond-Italic"
    static let hebrewQuotePostScript = "BonaNova-Regular"
    static let hebrewAuthorPostScript = "BonaNova-Italic"

    /// Register bundled TTFs once per process (required for WidgetKit / chronod).
    static func registerIfNeeded() {
        _ = registration
    }

    private static let registration: Bool = {
        let fileNames = [
            "CormorantGaramond-Regular",
            "CormorantGaramond-Italic",
            "BonaNova-Regular",
            "BonaNova-Italic",
        ]
        for name in fileNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
        return true
    }()

    static func quote(_ size: CGFloat = 20, isHebrew: Bool = false) -> Font {
        registerIfNeeded()
        let name = isHebrew ? hebrewQuotePostScript : latinQuotePostScript
        return .custom(name, size: size)
    }

    static func author(_ size: CGFloat = 14, isHebrew: Bool = false) -> Font {
        registerIfNeeded()
        let name = isHebrew ? hebrewAuthorPostScript : latinAuthorPostScript
        return .custom(name, size: size)
    }
}
