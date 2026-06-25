# ClickShot — Technical Decisions

Non-obvious approaches and the reasons behind them. Add a short entry whenever a
workaround, OS quirk, or tradeoff drives an implementation choice, so it isn't
re-litigated later. See `PRD.md` for the product/feature spec.

## Input handling

- **Mouse triggers observe, never swallow, button events.** Consuming the
  `otherMouseDown` at the session event tap stops the window server from
  generating `otherMouseDragged` events and freezes the cursor — so the drag
  could never start. We let the down/drag/up flow through and only watch them.
  Side effect: the app under the pointer also receives the click (acceptable).
- **Keyboard triggers use an interactive key window**, not the passive tap-driven
  overlay: tapping the hotkey opens `CrosshairSelectionController`, which owns the
  crosshair cursor and the press-drag-release selection. A borderless `NSWindow`
  cannot become key by default, so `KeyableBorderlessWindow` overrides
  `canBecomeKey`/`canBecomeMain` (needed to receive Esc and own the drag).
- **Hotkey matching** compares the recorded key code + the relevant modifier subset
  (⌘⌥⌃⇧) from the live `CGEventFlags`; the hotkey's own key events are swallowed so
  the character isn't typed.
- **Event tap resilience:** re-enable the tap on `tapDisabledByTimeout` /
  `tapDisabledByUserInput`.

## Cursor

- **Crosshair cursor during a mouse drag** is achieved by activating the app
  (`NSApp.activate`) on crossing the threshold and calling `NSCursor.crosshair.set()`
  on each drag event. `CGDisplayHideCursor`/`NSCursor` only affect the foreground
  app, so a background `.set()` is overridden by the app that owns the pointer;
  drawing a fake cursor instead lagged and left the real arrow visible.

## Capture

- **Coordinates:** work in AppKit global (bottom-left) internally; convert to the
  target display's backing pixels with a Y-flip for the ScreenCaptureKit crop.
- Capture targets the display containing the **center** of the selection.

## Signing & permissions

- **Signing & TCC:** sign with a stable identity (Developer ID, hardened runtime,
  secure timestamp). TCC keys off the designated requirement, so a stable signature
  keeps Accessibility/Screen Recording grants across rebuilds. Note: a team's
  **first** notarization can take hours to ~3 days (later ones are minutes).
