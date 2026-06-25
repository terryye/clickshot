# ClickShot — Technical Decisions

Non-obvious approaches and the reasons behind them. Add a short entry whenever a
workaround, OS quirk, or tradeoff drives an implementation choice, so it isn't
re-litigated later. See `PRD.md` for the product/feature spec.

## Input handling

- **Two independent triggers (middle button on/off + optional keyboard shortcut),
  routed by event category.** Key events drive the keyboard/crosshair path; mouse
  events drive the middle-button drag path; both can be active at once. They are
  made **mutually exclusive while mid-gesture**: mouse events are ignored while a
  keyboard crosshair session is active (`crosshair.isActive`), and the hotkey is
  ignored while a mouse gesture is in progress (mouse `state != .idle`). The mouse
  trigger is intentionally limited to the **middle button** — left/right/other are
  poor choices that would collide with normal use.
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
- **The interactive overlay must paint non-transparent pixels everywhere.** A fully
  clear region of the crosshair window lets mouse-downs and cursor updates pass
  through to the app below — so selection only started over the (drawn) hint banner
  and the crosshair cursor reverted. In the macOS overlay style we paint an
  imperceptible base fill (alpha ≈ 0.01) across the whole window, and use a
  `cursorUpdate` tracking area to keep the crosshair cursor from reverting.
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
- **Capture targets the display with the largest overlap** with the selection
  (`SelectionRendering.targetScreen`), not the one under the selection's center.
  Overlap-area is robust when the center lands in a bezel gap between unaligned
  monitors. The selection is then **clamped to that display's frame** before the
  crop, so a region straddling two monitors is captured from one (spanning capture
  is a non-goal; the off-display part is dropped).

## Multi-display

- **One overlay window per `NSScreen`, never a single union-spanning window.** With
  "Displays have separate Spaces" enabled (the macOS default) a window is clipped to
  one display's Space and never appears on the others — so a union-frame overlay left
  every secondary monitor undimmed and non-interactive. Both overlays
  (`SelectionOverlayController`, `CrosshairSelectionController`) now create a
  borderless window per display.
- **Shared selection state for the interactive crosshair.** With per-display windows
  the selection can't live in a single view: the press may land on one monitor and
  the drag cross onto another. State (start/current point, phase) lives in
  `CrosshairSelectionController`; each view forwards mouse points and reads back the
  rect to draw. macOS keeps delivering a drag to the window that got the mouse-down,
  which converts `locationInWindow` to global coords correctly even off its own
  display, so cross-monitor drags track. Only the display owning the selection draws
  the size label.
- **Compare screens by frame, not `NSScreen` identity.** `NSScreen` uses identity
  `==` and `NSScreen.screens` may return fresh instances per call, so comparing
  `NSScreen` objects (or `window.screen`) is unreliable. Screen frames are unique and
  non-overlapping in the global coordinate space, so frame equality identifies a
  display dependably.

## Signing & permissions

- **Signing & TCC:** sign with a stable identity (Developer ID, hardened runtime,
  secure timestamp). TCC keys off the designated requirement, so a stable signature
  keeps Accessibility/Screen Recording grants across rebuilds. Note: a team's
  **first** notarization can take hours to ~3 days (later ones are minutes).

## Branding / icons

- **Menu-bar glyph is drawn in code, not bundled as a raster.** The build is a
  hand-assembled bundle with no asset catalog, so `StatusBarController.makeMenuBarIcon()`
  renders the "Capture C" mark via `NSBezierPath` into a template `NSImage`. This
  stays crisp at any menu-bar size/scale and AppKit tints it for light/dark. The
  vector source of truth is `logo/logo-capture-c.svg`; the code mirrors its 24-unit
  grid (open ring with a ±38° gap on the right + a crosshair plus).
- **App icon is generated, then committed.** `scripts/make-appicon.sh` draws the
  same mark on a macOS squircle tile (Core Graphics, matching
  `logo/logo-capture-c-icon.svg`), emits every iconset size, and packs
  `Resources/AppIcon.icns` with `iconutil`. `build-app.sh` copies it into the
  bundle and `Info.plist` references it via `CFBundleIconFile`. Re-run the script
  when the design changes. (Drawn in code rather than rasterizing the SVG because
  stock macOS has no reliable SVG→PNG CLI that preserves alpha/gradients.)
- **`build-app.sh` re-registers the bundle with `lsregister -f` after signing.**
  Rebuilding `ClickShot.app` in place does not invalidate the LaunchServices /
  Finder icon cache — if the bundle was first registered without an icon, Finder
  keeps drawing the generic app icon even after a valid `.icns` is added. Forcing
  re-registration each build makes the current icon show without a Finder restart.
