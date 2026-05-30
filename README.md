# AutoClicker

AppKit-based macOS automation app scaffold with three focused workflows:

- **Auto Clicker** for repeatedly triggering a mouse click or keyboard combo at a configurable interval.
- **Key Holder** for holding a custom keyboard combo or mouse button in toggle or while-pressed mode.
- **Macro** for naming, building, recording, saving, and replaying click/key/pause sequences.

## Project layout

- `/Sources/AutoClicker/AppKit` — macOS app bootstrap, coordinator, accessibility, hotkeys, and recording.
- `/Sources/AutoClicker/Tabs` — per-tab AppKit view controllers.
- `/Sources/AutoClicker/Views` — reusable AppKit controls.
- `/Sources/AutoClicker/Models` and `/Services` — shared models, persistence, playback, and automation logic.
- `/Tests/AutoClickerTests` — platform-safe tests for persistence and macro playback behavior.

## Running

- On **macOS**, open the package in Xcode or build with Swift Package Manager and run the `AutoClickerApp` executable.
- On non-macOS platforms, the executable prints a platform notice while shared logic and tests still build.

## Permissions

The macOS app requests **Accessibility** access so it can:

- post keyboard and mouse events
- listen for global hotkeys
- record live input into macros