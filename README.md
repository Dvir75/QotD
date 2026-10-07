# QotD

macOS Desktop Widget + companion app for personal quotes that rotate on a schedule.

## Requirements

- macOS 15 Sequoia+
- Xcode 16+

## Setup

1. Open `QotD.xcodeproj` in Xcode.
2. Select the **QotD** target → **Signing & Capabilities** → choose your Team (Personal Team is fine).
3. Confirm App Group `group.com.dviramitai.QotD` is enabled on **QotD** and **QotDWidgetExtension** (Xcode may ask you to create the group on your team).
4. Run the **QotD** scheme on your Mac.
5. Add the widget: right-click Desktop → **Edit Widgets** → find **QotD**.

If you change `project.yml` and need to regenerate the project:

```bash
xcodegen generate
```

## Verify

```bash
# Rotation logic smoke test
swift Scripts/rotation_smoke_test.swift

# Compile (optional; uses local DerivedData)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project QotD.xcodeproj -scheme QotD -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

### Manual checklist (your Mac / Dad’s Mac)

- [ ] Add quote with author; blank author shows as **Unknown**
- [ ] Edit, delete, reorder quotes
- [ ] Widget shows quote + author; empty state when no quotes
- [ ] Sequential and random (no-repeat) modes
- [ ] Preset + custom interval; quote stays until interval ends
- [ ] Quit app — widget still shows/rotates
- [ ] Sleep/wake — same quote until interval ends

## Updates (Sparkle)

In-app updates download from the public [`QotD-updates`](https://github.com/dvir75/QotD-updates) repo (binaries + appcast only). Source stays in the private `QotD` repo.

**Ship a new version**

1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, then `xcodegen generate`.
2. Archive a Release build in Xcode and zip the `.app`.
3. Put the zip in a staging folder and run:

```bash
./Tools/Sparkle/bin/generate_appcast /path/to/staging
```

4. Create a GitHub Release on **QotD-updates** attaching the zip and `appcast.xml`.

Dad (or you): **Check for Updates…** in Settings or the menu-bar extra.

Sparkle signing keys live in your Mac login Keychain (`generate_keys`). Do not commit private keys. Local Sparkle CLI tools live under `Tools/Sparkle/` (gitignored); re-download from [Sparkle releases](https://github.com/sparkle-project/Sparkle/releases) if missing.

## Docs

- [PLAN.md](PLAN.md) — v1 scope
- [FUTURE.md](FUTURE.md) — deferred ideas
