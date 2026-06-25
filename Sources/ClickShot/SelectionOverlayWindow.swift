import AppKit

/// Manages a borderless, transparent overlay window **per display**. It dims the
/// desktop and draws the live selection rectangle during a capture drag.
///
/// One window per screen (rather than a single window spanning the union of all
/// screens) is required: with "Displays have separate Spaces" enabled — the macOS
/// default — a single window is clipped to one display and never appears on the
/// others. See `TECH_DECISIONS.md`.
final class SelectionOverlayController {
    private var overlays: [(window: NSWindow, view: OverlayView)] = []

    /// Shows an overlay on every screen.
    func show() {
        hide()
        for screen in NSScreen.screens {
            let frame = screen.frame
            let window = NSWindow(
                contentRect: frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.hasShadow = false

            let view = OverlayView(frame: NSRect(origin: .zero, size: frame.size))
            view.windowOrigin = frame.origin
            view.screenFrame = frame
            window.contentView = view
            window.orderFrontRegardless()

            overlays.append((window, view))
        }
    }

    /// Updates the selection rectangle (in AppKit global coordinates) on every
    /// overlay. Only the display owning the selection draws the size label.
    func update(selection rect: CGRect) {
        let labelFrame = SelectionRendering.targetScreen(for: rect)?.frame
        for (_, view) in overlays {
            view.selectionRect = rect
            // Compare by frame: NSScreen uses identity equality and may hand back
            // fresh instances, so `==` between NSScreen objects is unreliable.
            view.drawsLabel = view.screenFrame == labelFrame
            view.needsDisplay = true
        }
    }

    func hide() {
        overlays.forEach { $0.window.orderOut(nil) }
        overlays.removeAll()
    }
}

/// Passive overlay used during a press-and-drag (mouse-button) capture. It does
/// not accept mouse events; the gesture is driven externally by the event tap.
final class OverlayView: NSView {
    /// Selection rectangle in AppKit global coordinates.
    var selectionRect: CGRect = .zero
    /// The overlay window's origin in global coordinates.
    var windowOrigin: CGPoint = .zero
    /// This overlay's screen frame in global coordinates (used to identify the
    /// display owning the selection without relying on `NSScreen` identity).
    var screenFrame: CGRect = .zero
    /// Whether this overlay (i.e. this display) draws the size/hint label.
    var drawsLabel: Bool = true

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        SelectionRendering.draw(
            in: ctx, bounds: bounds,
            selectionRect: selectionRect, windowOrigin: windowOrigin,
            style: Preferences.shared.overlayStyle,
            drawsLabel: drawsLabel
        )
    }
}
