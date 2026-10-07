import Foundation
import WidgetKit

/// macOS keeps WidgetKit extensions alive under `chronod`. Xcode Debug builds used to
/// ship a `.debug.dylib` stub that only works while the debugger is attached — after
/// that chronod relaunches the appex and the desktop widget stays on gray bars.
/// We disable that stub (`ENABLE_DEBUG_DYLIB = NO`) and still poke chronod on launch.
enum WidgetExtensionRelauncher {
    private static let lastBuildKey = "qotd.lastLaunchedBuild"

    static func relaunchIfBuildChanged() {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: lastBuildKey)
        let buildChanged = previous != current
        defaults.set(current, forKey: lastBuildKey)

        if buildChanged {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            task.arguments = ["-9", "QotDWidgetExtension"]
            try? task.run()
            task.waitUntilExit()
        }

        // Always ask WidgetKit to refresh — gray bars after re-add are often a
        // stale timeline that never gets replaced until something triggers reload.
        WidgetCenter.shared.reloadTimelines(ofKind: QotDWidgetKind.current)
        WidgetCenter.shared.reloadAllTimelines()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            WidgetCenter.shared.reloadTimelines(ofKind: QotDWidgetKind.current)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
