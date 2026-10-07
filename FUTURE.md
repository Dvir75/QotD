# QotD — later / not v1

Ideas deferred from planning. Review when shaping post-launch work.

## Top priority

- **Hebrew UI localization** — localize companion chrome (sidebar, Settings, buttons) and mirror app layout.

## From grill decisions

- **Favorites / pin in companion app** — pin or favorite quotes from the app list (menu-bar pin/hold is implemented).
- **Pin and set as active from Quotes list** — pin and/or jump the rotation to a selected quote from the companion list.
- **Drag and reorder overhaul** — improve Quotes list drag-to-reorder feel and reliability.
- **Launch at login / always-on menu extra** — extra exists only while QotD is launched; widget still rotates after Quit.
- **Categories / tags** — organize beyond a flat list (e.g. “Dad”, “Motivation”).
- **Appearance customization** — presets, font size, text color, background opacity (v1 is system default look only).
- **Richer first-run** — sample quotes and/or onboarding that offers samples vs start blank (v1 is empty state only).
- **iCloud sync** — sync quotes and settings across devices (v1 is local-only via App Group).
- **Wider distribution** — notarized download and/or Mac App Store (v1 is install from Xcode / personal use).

## Ideas

Out of scope for v1; possible later:

- Share quotes
- AI-generated quotes
- Reminders / notifications
- Multiple widget instances with different lists
- Import / export
- Images behind quotes

_(Add more here as they come up.)_

## Implemented

Done; kept here for history / so we don’t re-queue them.

- **Smart paste on add (QOL)** — first paste into empty Quote (add only): always split (patterns A–C); optional Cleanup + Auto-capitalize (Settings + new-quote checkboxes, default on); Save/typing/edit stay dumb. See prior grill notes for prefix lists and patterns.
- **Hebrew quote content** — per-quote RTL from Hebrew text, Bona Nova for Hebrew / Cormorant for Latin, mirrored attribution, live editor flipping, `לא ידוע` fallback; app chrome stays English/LTR.
- **macOS App Groups** — Team-ID–prefixed ID (`55FZJ4852Q.com.dviramitai.QotD`), not iOS `group.…`.
- **Menu bar extra** — Pin / Next / Quotes / Settings / Quit while the app process is running. Widget click (`qotd://menu`) starts the process if needed and pops the extra without opening the window. Dock still opens the window. Close window keeps the extra; Quit removes it. Widget stays glance-only (no overlay buttons).
