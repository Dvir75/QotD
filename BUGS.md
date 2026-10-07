# Bugs

## Open

_(none)_

## Fixed / notes

- **Menu extra popped at the top-left on first widget click:** `performClick` ran before the status item had a screen frame. Wait until the button is laid out (`minX > 8`) then click.
- **Quotes / Settings / Dock did not open the window** after menu extra: `applicationShouldHandleReopen` returned false (blocked SwiftUI from recreating the window) and `openWindow` lived only inside the closed window. Close is now hide (`orderOut`); reopen returns true; main window is tracked.
- **Quotes / Settings after widget start:** `handlesExternalEvents(matching: [])` skipped creating `Window(id: "main")` on `qotd://menu` launch, so extra items had nothing to reveal until Dock created the scene. Quotes/Settings/Dock materialize or reveal the window; widget URL does not.
- **Menu extra icon vanished / menu at top-left:** `hide()` ordered out any `canBecomeMain` window, including the status item. Only the main app window is hidden; extra pop waits for a real menu-bar frame and does not click at the origin.

- Plus (+) button dims to gray when the app/window is not in focus (matches other controls).
- **Amount** in custom interval: nested under Interval (no peer row/duplicate value); bordered field; seconds unit.
- Rotation mode label shows **Random** (not “Random (no repeats)”).
- Custom no longer duplicated in the interval picker.
- App Group sharing works (store + preview keys under `55FZJ4852Q.com.dviramitai.QotD`).
- Gray bars after re-add = chronod stuck on redacted placeholder.
  - Fix: `ENABLE_DEBUG_DYLIB = NO` on widget target, kind **QotDWidgetV9**, timeline only reads UserDefaults preview keys.
- Stale widget binaries: kill extension / chronod after rebuild; remove + re-add widget.
- Widget tap spawning windows: single `Window(id: "main")` + focus via AppDelegate. Widget tap now pops the menu extra (`qotd://menu`) and does not open the window.
- Floating desktop quote panel removed (system widget is the surface).
- **Widget pin/next controls invisible (V12–V14) / overlay layout (V18):** superseded. Pin/Next live in the menu extra; widget is quote + author only.
- **Widget Link pin/next opens app:** expected for `Link` / `widgetURL`. Pin/Next are no longer widget controls.
- **V16 blank quote / placeholder with stale V15 chrome:** `.frame(maxHeight: .infinity)` / `.glassEffect` archival issues; widget chrome removed in V19.
- **V17 quote stuck small at top:** Spacer band; V18 overlay scaled type; V19 glance-only card (no control reserve).
