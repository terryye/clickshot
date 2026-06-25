import AppKit

/// Manages a borderless, transparent overlay window spanning every screen. It
/// dims the desktop and draws the live selection rectangle during a capture drag.
final class SelectionOverlayController {
    private var window: NSWindow?
    private var overlayView: OverlayView?

    /// Shows the overlay across the union of all screens.
    func show() {
        let frame = SelectionRendering.unionFrame()

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
        window.contentView = view
        window.orderFrontRegardless()

        self.window = window
        self.overlayView = view
    }

    /// Updates the selection rectangle (in AppKit global coordinates).
    func update(selection rect: CGRect) {
        overlayView?.selectionRect = rect
        overlayView?.needsDisplay = true
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        overlayView = nil
    }
}

/// Passive overlay used during a press-and-drag (mouse-button) capture. It does
/// not accept mouse events; the gesture is driven externally by the event tap.
final class OverlayView: NSView {
    /// Selection rectangle in AppKit global coordinates.
    var selectionRect: CGRect = .zero
    /// The overlay window's origin in global coordinates.
    var windowOrigin: CGPoint = .zero

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        SelectionRendering.draw(
            in: ctx, bounds: bounds,
            selectionRect: selectionRect, windowOrigin: windowOrigin, dim: true
        )
    }
}
