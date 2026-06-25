# ClickShot

A lightweight macOS menu-bar screenshot tool with a **mouse-drag capture gesture**.

Press and hold your trigger (default: **middle mouse button**), drag past ~20px to
start selecting, and release to copy the selected region straight to the clipboard.

## Features

- **Drag-to-capture**: press the trigger, drag to draw a free rectangle, release to copy.
- **Configurable trigger**: any mouse button *or* a keyboard shortcut.
- **Menu-bar app**: no Dock icon; a `viewfinder` icon lives in the status bar.
- **Settings**: launch-at-login toggle, trigger recorder, and permission status.
- Built on **ScreenCaptureKit** (macOS 14+), native Swift + AppKit.

## Build & run

```sh
./scripts/build-app.sh          # release build → build/ClickShot.app
open build/ClickShot.app
```

On first launch, grant ClickShot two permissions in **System Settings ▸ Privacy & Security**:

- **Accessibility** — required to detect the global trigger gesture.
- **Screen Recording** — required to capture the screen.

The Settings window (status-bar icon ▸ Settings…) shows the live status of both and
has buttons to open the relevant panes.

## Usage

1. Hold the **middle mouse button** (or your configured trigger).
2. Drag to draw a selection rectangle (a dimmed overlay appears once you pass the threshold).
3. Release to copy the screenshot to the clipboard. Paste with ⌘V.
4. Press **Esc** mid-drag to cancel.

A plain trigger click (no drag) passes through to the app underneath.

## Project layout

| Path | Purpose |
|------|---------|
| `Sources/ClickShot/EventTapManager.swift` | Global `CGEvent` tap. |
| `Sources/ClickShot/CaptureController.swift` | Gesture state machine + plain-click replay. |
| `Sources/ClickShot/SelectionOverlayWindow.swift` | Dimmed overlay + selection rectangle. |
| `Sources/ClickShot/ScreenCapturer.swift` | ScreenCaptureKit capture + crop. |
| `Sources/ClickShot/ClipboardWriter.swift` | Writes the image to the pasteboard. |
| `Sources/ClickShot/StatusBarController.swift` | Menu-bar item + menu. |
| `Sources/ClickShot/SettingsWindow.swift` | Settings UI + trigger recorder. |
| `Sources/ClickShot/LoginItemManager.swift` | Launch-at-login via `SMAppService`. |

## Notes

- TCC permissions are tied to the signed bundle; rebuilding with ad-hoc signing may
  require re-granting Accessibility / Screen Recording.
- Captures the display containing the center of the selection.
