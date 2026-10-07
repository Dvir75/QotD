# QotD — v1 plan

## Goal

Desktop Widget that shows user-managed quotes, rotating on a chosen interval, with a companion Mac app for quotes and settings.

## Product (locked)

| Area | Decision |
|------|----------|
| Surface | WidgetKit Desktop Widget (glance-only) + companion window + menu extra while launched |
| Quit behavior | Widget fully works and rotates when the app is quit. Menu extra exists only while QotD is running. |
| Minimum OS | macOS 15 Sequoia |
| Quotes | Add / edit / delete / reorder; flat list |
| Quote fields | Body (required) + author (optional; default **"Unknown"**) |
| Display | Quote body, then author on a second line (smaller / muted / “— Author” style) in app list and widget |
| Rotation | User chooses mode; random = no repeats until full list shown; also sequential |
| Interval | Presets + custom; current quote stable until interval ends |
| First run | Empty state (“Add quotes in QotD”) |
| Appearance | System default widget look; light/dark follows system |
| Stack | Swift + SwiftUI (app + widget extension) |
| Data | Local only; App Group shared with widget |
| Distribution | Install from Xcode / personal use |
| Privacy | No accounts, analytics, or network |

Deferred and ideas: see `FUTURE.md`.

## Architecture (high level)

1. **App target** — quote list CRUD + reorder; settings (rotation mode, interval); empty state.
2. **Widget extension** — reads shared state; timeline entries until `nextChangeDate`.
3. **Shared layer (App Group)** — quotes, settings, `currentQuoteId`, `nextChangeDate`, rotation progress (e.g. shown IDs for no-repeat mode).
4. **Reload** — when app saves quotes/settings, write shared store and `WidgetCenter.shared.reloadTimelines`.

## Suggested data shape

- `Quote`: `id`, `text`, `author` (default `"Unknown"`), `sortOrder`
- `Settings`: `rotationMode` (sequential | randomNoRepeat), `interval` (preset or custom `TimeInterval`)
- `PlaybackState`: `currentQuoteId`, `nextChangeDate`, `shownQuoteIds` (for random cycle)

## Build order

1. Xcode project: macOS app + Widget Extension; App Group; deployment target 15.
2. Shared models + App Group persistence.
3. Companion UI: list, add/edit (text + author), delete, reorder, empty state.
4. Settings UI: rotation mode + interval (presets + custom).
5. Rotation engine: advance when `nextChangeDate` passes; persist stable current quote.
6. Widget UI: body + author line; empty placeholder; timeline provider.
7. Wire app saves → shared store → widget reload.
8. Manual test on your Mac and Dad’s Mac (add quotes, intervals, quit app, sleep/wake).

## Done when

- User can manage quotes (with author defaulting to Unknown) and reorder them.
- User can set rotation mode and interval.
- Widget shows the current quote (+ author) and advances on schedule with the app quit.
- Empty states are clear in app and widget.
