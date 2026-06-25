# ClickShot — Product Requirements Document

## Overview

ClickShot is a lightweight, native macOS menu-bar utility for capturing a screen
region to the clipboard using a **mouse-drag gesture** or a **keyboard shortcut**,
without the friction of the system screenshot keys. It lives in the status bar,
runs invisibly (no Dock icon), and copies the selected area straight to the
clipboard for immediate pasting.

- **Platform:** macOS 14 (Ventura+); built with Swift + AppKit + ScreenCaptureKit.
- **Distribution:** Developer ID signed, hardened runtime, notarizable.
- **App type:** Menu-bar accessory app (`LSUIElement`), no Dock icon, no main window.

## Goals

- Capture any screen region to the clipboard in one fluid gesture.
- Offer a fast pointer-driven trigger (default: middle mouse button) for power users.
- Offer a familiar keyboard-shortcut + crosshair flow matching the macOS screenshot tool.
- Stay out of the way: menu-bar only, minimal configuration, instant clipboard output.

## Non-goals (current version)

- Saving screenshots to files (clipboard-only for now).
- Annotation / markup, scrolling capture, window/element capture, timed capture.
- Video/GIF recording.
- Capturing a region that spans multiple displays (capture targets the display
  under the selection's center).

---

## Features

### 1. Configurable capture trigger
- The trigger can be **any mouse button** (default: **middle button**) **or** a
  **keyboard shortcut** with modifiers.
- Recorded via a "press to record" control in Settings; the next mouse button or
  key combination pressed becomes the trigger.
- Persisted in `UserDefaults`; changes take effect immediately (no relaunch).

### 2. Mouse-button trigger — press-and-drag capture
- **Press and hold** the trigger button, **drag** past the **drag threshold**
  (default **5 px**), and a dimmed selection overlay appears.
- The selection rectangle tracks the pointer live, showing a size label (W × H).
- **Release** the button → the selected region is captured to the clipboard.
- **Esc** during the drag cancels without capturing.
- Events are **observed, not swallowed**, so the window server keeps generating
  drag events and the cursor stays live (a normal click that never crosses the
  threshold does nothing special).

### 3. Keyboard-shortcut trigger — crosshair capture (macOS-style)
- **Tap** the configured hotkey → ClickShot enters crosshair mode: the screen
  dims slightly, a hint banner appears, and the cursor becomes a crosshair `+`.
- **Press and hold the left mouse button**, drag to size the selection, and
  **release** to capture to the clipboard.
- **Esc** cancels crosshair mode.
- The hotkey keystroke is suppressed so it isn't typed into the focused app.

### 4. Selection overlay
- Free-rectangle selection (any width/height).
- Dimmed backdrop with a clear "window" over the selected area, an accent-colored
  border, and a live **W × H** size label.
- Spans all connected displays.

### 5. Screen capture
- Uses **ScreenCaptureKit** (`SCScreenshotManager`).
- Correctly handles **Retina scaling** and the AppKit↔Quartz Y-axis flip.
- Targets the display containing the center of the selection (multi-monitor aware).

### 6. Clipboard output
- Captured image is written to the general pasteboard as both **PNG** and **TIFF**
  for broad app compatibility. Paste with ⌘V anywhere.

### 7. Menu-bar presence & settings
- Always-visible status-bar item (`viewfinder` SF Symbol).
- Menu: **Settings…**, **Quit** (a Launch-at-Login menu toggle is also available).
- **Settings window** contains:
  - **Capture trigger** recorder (shows current trigger, e.g. "Middle Mouse Button"
    or "⌃⌥S").
  - **Launch at login** checkbox.
  - **Permissions** status rows for Accessibility and Screen Recording, each with
    an "Open Settings" deep link.

### 8. Launch at login
- Toggle registers/unregisters the app via **`SMAppService`** (macOS 13+).

### 9. Permissions handling
- Requires **Accessibility** (for the global event tap) and **Screen Recording**
  (for capture).
- On launch, missing permissions are requested; the app polls and starts the event
  tap as soon as Accessibility is granted (no relaunch needed).
- Settings shows live grant status with quick links to the relevant System
  Settings panes.

### 10. Configurable drag threshold
- Minimum pointer travel before a press becomes a capture drag.
- Default **5 px**; stored in `UserDefaults` (`dragThreshold`) and adjustable
  (currently via `defaults write com.clickshot.app dragThreshold -float N` or in code).

---

## Interaction summary

| Trigger type | Activate | Select | Finish | Cancel |
|--------------|----------|--------|--------|--------|
| Mouse button (default: middle) | Press & hold the button | Drag past 5 px | Release the button | Esc |
| Keyboard shortcut | Tap the hotkey | Hold left button & drag | Release left button | Esc |

---

## Technical requirements

- **Global input:** `CGEvent` tap (`cgSessionEventTap`) for mouse and keyboard;
  re-enables itself on `tapDisabledByTimeout`.
- **Coordinate handling:** AppKit global (bottom-left) internally; converted to
  display backing pixels with Y-flip for capture/crop.
- **Signing/distribution:** `scripts/build-app.sh` assembles the `.app`, auto-detects
  a signing identity (Developer ID → Apple Development → ad-hoc), and signs with
  hardened runtime + secure timestamp. `scripts/notarize.sh` submits, staples, and
  verifies via `notarytool`.
- **Permissions persistence:** signing with a stable identity (Developer ID) keeps
  TCC grants across rebuilds.

## Key components

| Component | Responsibility |
|-----------|----------------|
| `EventTapManager` | Global `CGEvent` tap; forwards events. |
| `CaptureController` | Routes triggers; mouse hold-drag state machine; capture + clipboard. |
| `CrosshairSelectionController` | Interactive crosshair key window for keyboard triggers. |
| `SelectionOverlayWindow` | Passive drag overlay. |
| `SelectionRendering` | Shared overlay drawing (dim, rectangle, size label). |
| `ScreenCapturer` | ScreenCaptureKit capture + crop. |
| `ClipboardWriter` | Writes PNG/TIFF to the pasteboard. |
| `StatusBarController` / `SettingsWindow` | Menu-bar item + settings UI + trigger recorder. |
| `TriggerConfig` / `Preferences` | Trigger model + persisted settings. |
| `LoginItemManager` / `Permissions` | Launch-at-login + TCC permission checks. |

## Future enhancements (candidates)

- Save-to-file option (with configurable location/format) alongside clipboard.
- In-UI drag-threshold control.
- Selection across multiple displays.
- Post-capture preview / quick annotation.
- Configurable capture sound / flash feedback.
