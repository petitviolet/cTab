# cTab Specification

> 日本語版: [specification_ja.md](specification_ja.md)
> Target version: cTab 0.1.0

---

## 1. Overview

cTab replaces macOS's built-in Command+Tab (which switches by app) with a **per-window** switcher. Holding a modifier and pressing the trigger key shows a grid of window thumbnails; selecting one brings that window to the front. It runs as a menu-bar-resident accessory app with no Dock icon.

---

## 2. Requirements

| Item | Detail |
| --- | --- |
| OS | macOS 14 or later (developed and tested on macOS 26) |
| Toolchain | Swift 6 (bundled with Xcode 26) |
| Dependencies | Apple system frameworks only; no third-party libraries. |
| Permissions | Accessibility (required), Screen Recording (optional, for thumbnails) |

---

## 3. Functional Requirements

### 3.1 Window switching

- Enumerates standard windows of regular apps (`activationPolicy == .regular`), including minimized ones.
- Orders windows front-to-back; the first is the frontmost window, and the initial selection is the "previous window" (index 1).
- Confirming a selection raises that window, un-minimizes it if needed, and activates its app.

### 3.2 Trigger and navigation

| Action | Default | Description |
| --- | --- | --- |
| Open, next | `Command`+`Tab` | show switcher / advance selection |
| Previous | `Command`+`Shift`+`Tab` | reverse |
| Move | `Command`+`←→↑↓` | move within the grid |
| Confirm | release `Command` (hold mode), `Return` (toggle mode) | |
| Cancel | `Escape` | |

The trigger modifier (Command / Option / Control) and key (Tab / backtick) are configurable and applied immediately. Choosing a non-Command modifier keeps the standard Command+Tab available.

### 3.3 Activation modes

- **Hold** (default): shown only while the modifier is held; releasing it confirms (same as the standard switcher).
- **Toggle**: stays open after releasing the modifier. `Return` confirms, `Escape` cancels, and the bare trigger key advances. Lets you take your time with mouse, arrows, or search.

### 3.4 Incremental search

Typing while the switcher is open filters by app name / window title (case-insensitive). `Backspace` deletes one character. The query is shown in a search bar. Works best with toggle mode. If the trigger key is set to backtick, the backtick (and `~`) cannot be typed into search.

### 3.5 Window actions

| Action | Key | Description |
| --- | --- | --- |
| Close | `Command`+`W` | closes the selected window (presses its close button) |
| Quit app | `Command`+`Q` | quits the app gracefully |
| Minimize | `Command`+`M` | minimizes the selected window |
| Fullscreen | `Command`+`F` | toggles fullscreen (via AXFullScreen, falling back to the fullscreen button) |

Action keys follow the trigger modifier (e.g. with an Option trigger, Option+W closes). Closing / quitting / minimizing removes the window from the list while the switcher stays open; it closes automatically once no windows remain.

### 3.6 Mouse

Click a cell to switch to that window. Hovering a cell shows a close button (×) at its top-right that closes the window. Mouse interaction works on the panel of the display where the cursor is.

### 3.7 Thumbnails

Window previews are captured with ScreenCaptureKit. Thumbnails are cached in memory per windowID; on open, the previous capture is shown instantly and refreshed in the background. There is no continuous background capture, so no persistent screen-recording indicator and no battery drain. Without Screen Recording permission, or before a capture completes, the app icon is shown instead.

### 3.8 Layout and size

The number of columns and cell size are computed to fit within the target display's visible area (no horizontal scrolling). The UI auto-scales with the target display's width, and a settings slider applies a multiplier (50–150%).

### 3.9 Multi-display

- By default the switcher appears on the display containing the frontmost window. "Show on all displays" can be enabled; each display is sized for its own resolution and the selection stays in sync.
- **Active-display indication**: cells for windows not on the display under the cursor get a black background to distinguish them, following the mouse in real time. The on/off state and blackness (background opacity) are configurable.

### 3.10 Spaces

A setting controls whether windows on other Spaces (not on the current Space's on-screen list and not minimized) are included or excluded (default: included). Selecting one switches to its Space.

### 3.11 Theme and appearance

Configurable appearance (system / light / dark), accent color for the selection border, and panel background opacity.

### 3.12 Misc

Launch at login (`SMAppService`), a settings window, and a menu-bar menu (open settings / restart / quit).

---

## 4. Architecture

### 4.1 Data flow

```
trigger key
  → EventTapController (CGEventTap intercepts and consumes the event)
  → SwitcherController.open (enumerate via WindowEnumerator)
  → SwitcherPanel.show (one NSPanel + SwiftUI per display)
  → update selection via tab / arrows / search
  → confirm on modifier release or Return
  → WindowActivator (AX raise + app activate)
```

### 4.2 Modules

```
Sources/cTab/
├── main.swift                 entry (accessory app)
├── App/
│   ├── AppDelegate.swift      permissions, menu bar, settings window, wiring
│   ├── AppSettings.swift      persisted settings (UserDefaults)
│   ├── SettingsWindowController.swift / SettingsModel.swift  settings window
│   ├── LoginItem.swift        login item (SMAppService)
│   └── Relauncher.swift       app restart
├── HotKey/
│   ├── HotKeyMatcher.swift    trigger & action matching (pure logic, tested)
│   └── EventTapController.swift   event tap creation, interception, recovery
├── Windows/
│   ├── WindowInfo.swift       window model
│   ├── WindowEnumerator.swift AX enumeration (+ private API for CGWindowID)
│   ├── WindowActivator.swift  raise, close, quit, minimize, fullscreen
│   ├── ThumbnailCapturer.swift / ThumbnailCache.swift   capture and cache
├── UI/
│   ├── SwitcherViewModel.swift   shared observable state
│   ├── SwitcherView.swift     SwiftUI grid, search bar, theme
│   ├── SwitcherPanel.swift    NSPanel (one per display)
│   └── SwitcherController.swift  orchestrator
└── Core/
    ├── Navigation.swift       selection cycling, grid moves (pure logic, tested)
    ├── GridLayout.swift       columns & cell sizing (pure logic, tested)
    └── Log.swift              os.Logger
```

### 4.3 Frameworks and key APIs

| Purpose | API |
| --- | --- |
| Trigger interception | `CGEvent.tapCreate` (session / headInsert / defaultTap), `keyDown` / `flagsChanged` |
| Enumeration | `NSWorkspace.runningApplications`, `AXUIElementCreateApplication`, `kAXWindowsAttribute`, `CGWindowListCopyWindowInfo`, private `_AXUIElementGetWindow` |
| Actions | `AXUIElementPerformAction(kAXRaiseAction)`, `kAXMinimizedAttribute`, `AXFullScreen`, `NSRunningApplication.activate/terminate` |
| Display | `NSPanel` (`.nonactivatingPanel`), SwiftUI + `NSHostingView` |
| Thumbnails | `SCShareableContent`, `SCScreenshotManager` (ScreenCaptureKit) |
| Launch | `SMAppService` (ServiceManagement) |

---

## 5. Settings

| Setting | Default | Range or options |
| --- | --- | --- |
| Trigger modifier | Command | Command / Option / Control |
| Trigger key | Tab | Tab / backtick |
| Activation mode | Hold | Hold / Toggle |
| Launch at login | OFF | ON / OFF |
| Show on all displays | OFF | ON / OFF |
| Include other Spaces | ON | ON / OFF |
| Switcher size | 100% | 50%–150% |
| Active-display highlight | ON | ON / OFF |
| Inactive black background | 100% (effective 50%) | 30%–100% |
| Appearance | System | System / Light / Dark |
| Accent color | System | System / Blue / Purple / Pink / Green / Orange / Red |
| Panel opacity | 100% | 50%–100% |

Settings are stored in `UserDefaults` (domain `net.petitviolet.cTab`); trigger / search / display options take effect from the next time the switcher is shown.

---

## 6. Permissions, Build, and Distribution

### 6.1 Permissions

Without Accessibility permission the event tap cannot be created and Command+Tab cannot be intercepted (the standard switcher appears). Screen Recording is only needed for thumbnails; without it the app falls back to icons.

### 6.2 Build and signing

A Swift Package Manager executable is built and wrapped into a `.app` bundle by a shell script (`scripts/build_app.sh`). TCC permissions are tied to the code signature's Designated Requirement, so ad-hoc signing (cdhash-based) loses permissions on every rebuild. Signing with a fixed self-signed certificate (created in a dedicated keychain by `scripts/build_app.sh cert`) makes the DR "bundle id + certificate"-based, so permissions persist across rebuilds. No Apple Developer Program is required.

### 6.3 Distribution

Distributing to others additionally requires Developer ID signing + notarization. The self-signed certificate is only for local permission persistence and does not pass Gatekeeper. The Mac App Store is out of scope because its mandatory sandbox conflicts with CGEventTap interception and private API usage.

---

## 7. Security and Privacy

- The event tap observes only `keyDown` / `flagsChanged`. While the switcher is hidden it consumes nothing but the trigger and passes everything else through.
- Characters are read only while the switcher is shown, for search, and are processed locally in memory without being stored or logged.
- Window titles and thumbnails are kept in memory only; nothing is written to disk or sent over the network.
- Logs never include sensitive information such as window titles (only counts, state, and pid).

---

## 8. Testing

Unit tests cover the pure-logic layer (`Navigation`, `GridLayout`, `HotKeyMatcher`, `WindowInfo`, `SwitcherViewModel`, `ThumbnailCache`) via `swift test` (45 tests). Side-effect layers (event tap, AX, ScreenCaptureKit, UI) are verified manually on a real machine.

---

## 9. Known Limitations

- The AX-window-to-CGWindowID mapping uses the private API `_AXUIElementGetWindow`, whose behavior may change in future macOS (windows for which it fails are skipped).
- Some windows on other Spaces or from certain apps may not be retrievable due to AX behavior.
- When displays have different column counts, vertical movement uses the column count of the first (frontmost-window) display.
- Mouse click / hover is most reliable on the panel of the display under the cursor.
