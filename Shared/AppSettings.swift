import Foundation

struct AppSettings: Codable, Equatable {
    var rotationMode: RotationMode
    /// Seconds between quote changes.
    var intervalSeconds: TimeInterval
    /// Legacy floating-panel flag (ignored; kept for store decode compatibility).
    var showDesktopQuote: Bool
    /// Strip quote marks / author prefixes on first smart paste (add only).
    var pasteCleanupEnabled: Bool
    /// Capitalize quote first letter + title-case author on first smart paste (add only).
    var pasteAutoCapitalizeEnabled: Bool

    static let `default` = AppSettings(
        rotationMode: .sequential,
        intervalSeconds: 86_400,
        showDesktopQuote: false,
        pasteCleanupEnabled: true,
        pasteAutoCapitalizeEnabled: true
    )

    enum CodingKeys: String, CodingKey {
        case rotationMode
        case intervalSeconds
        case showDesktopQuote
        case pasteCleanupEnabled
        case pasteAutoCapitalizeEnabled
    }

    init(
        rotationMode: RotationMode,
        intervalSeconds: TimeInterval,
        showDesktopQuote: Bool,
        pasteCleanupEnabled: Bool = true,
        pasteAutoCapitalizeEnabled: Bool = true
    ) {
        self.rotationMode = rotationMode
        self.intervalSeconds = intervalSeconds
        self.showDesktopQuote = showDesktopQuote
        self.pasteCleanupEnabled = pasteCleanupEnabled
        self.pasteAutoCapitalizeEnabled = pasteAutoCapitalizeEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rotationMode = try container.decode(RotationMode.self, forKey: .rotationMode)
        intervalSeconds = try container.decode(TimeInterval.self, forKey: .intervalSeconds)
        showDesktopQuote = try container.decodeIfPresent(Bool.self, forKey: .showDesktopQuote) ?? false
        pasteCleanupEnabled = try container.decodeIfPresent(Bool.self, forKey: .pasteCleanupEnabled) ?? true
        pasteAutoCapitalizeEnabled = try container.decodeIfPresent(Bool.self, forKey: .pasteAutoCapitalizeEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rotationMode, forKey: .rotationMode)
        try container.encode(intervalSeconds, forKey: .intervalSeconds)
        try container.encode(showDesktopQuote, forKey: .showDesktopQuote)
        try container.encode(pasteCleanupEnabled, forKey: .pasteCleanupEnabled)
        try container.encode(pasteAutoCapitalizeEnabled, forKey: .pasteAutoCapitalizeEnabled)
    }

    static let presets: [(title: String, seconds: TimeInterval)] = [
        ("5 seconds (debug)", 5),
        ("15 minutes", 15 * 60),
        ("1 hour", 60 * 60),
        ("6 hours", 6 * 60 * 60),
        ("1 day", 86_400),
        ("1 week", 7 * 86_400),
    ]
}

enum RotationMode: String, Codable, CaseIterable, Identifiable {
    case sequential
    case randomNoRepeat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequential: "Sequential"
        case .randomNoRepeat: "Random"
        }
    }
}
