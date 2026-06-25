import AppKit

/// Manages a borderless, transparent overlay window spanning every screen. It
/// dims the desktop and draws the live selection rectangle during a capture drag.
final class SelectionOverlayController {
    private var window: NSWindow?
    private var overlayView: OverlayView?

    /// Shows the overlay across the union of all screens.
    func show() {
        let frame = SelectionOverlayController.unionFrame()

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

    /// The smallest rectangle (in AppKit global coordinates) containing all screens.
    private static func unionFrame() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }
}

/// Draws the dimmed backdrop, the clear selection window, its border, and a size
/// label. Coordinates arrive in AppKit global space and are offset by the window
/// origin to become view-local.
final class OverlayView: NSView {
    /// Selection rectangle in AppKit global coordinates.
    var selectionRect: CGRect = .zero
    /// The overlay window's origin in global coordinates.
    var windowOrigin: CGPoint = .zero

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let local = CGRect(
            x: selectionRect.origin.x - windowOrigin.x,
            y: selectionRect.origin.y - windowOrigin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )

        // Dim everything, then punch a clear hole for the selection.
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
        ctx.fill(bounds)
        ctx.clear(local)

        guard selectionRect.width >= 1, selectionRect.height >= 1 else { return }

        // Selection border.
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(local.insetBy(dx: 0.75, dy: 0.75))

        drawSizeLabel(for: local)
    }

    private func drawSizeLabel(for local: CGRect) {
        let text = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let boxSize = CGSize(width: size.width + padding * 2, height: size.height + padding)

        var boxOrigin = CGPoint(x: local.minX, y: local.maxY + 6)
        if boxOrigin.y + boxSize.height > bounds.maxY {
            boxOrigin.y = local.maxY - boxSize.height - 6  // Flip below the top edge.
        }
        boxOrigin.x = max(bounds.minX, min(boxOrigin.x, bounds.maxX - boxSize.width))

        let box = CGRect(origin: boxOrigin, size: boxSize)
        let path = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.65).setFill()
        path.fill()

        text.draw(
            at: CGPoint(x: box.minX + padding, y: box.minY + padding / 2),
            withAttributes: attributes
        )
    }
}
