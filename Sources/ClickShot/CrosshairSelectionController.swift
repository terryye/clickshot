import AppKit
import Carbon.HIToolbox

/// Interactive crosshair selection used by keyboard triggers, mirroring the macOS
/// screenshot flow: the cursor becomes a crosshair, the first click sets the start
/// corner, moving updates the selection, and the second click captures.
///
/// Unlike the press-and-drag overlay, this is a *key* window that handles its own
/// mouse and keyboard events.
final class CrosshairSelectionController {
    private var window: NSWindow?
    private var view: CrosshairOverlayView?
    private var onComplete: ((CGRect?) -> Void)?

    var isActive: Bool { window != nil }

    /// Presents the crosshair overlay. `completion` receives the selected rect in
    /// AppKit global coordinates, or `nil` if cancelled.
    func begin(completion: @escaping (CGRect?) -> Void) {
        guard window == nil else { return }
        onComplete = completion

        let frame = SelectionRendering.unionFrame()
        let win = KeyableBorderlessWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.hasShadow = false
        win.acceptsMouseMovedEvents = true

        let v = CrosshairOverlayView(frame: NSRect(origin: .zero, size: frame.size))
        v.windowOrigin = frame.origin
        v.controller = self
        win.contentView = v

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(v)
        NSCursor.crosshair.push()

        window = win
        view = v
    }

    /// Called by the view when the user finishes (second click) or cancels (Esc).
    func finish(rect: CGRect?) {
        NSCursor.pop()
        window?.orderOut(nil)
        window = nil
        view = nil
        let callback = onComplete
        onComplete = nil
        callback?(rect)
    }
}

/// A borderless window that is still allowed to become key, so it can receive
/// keyboard events (Esc) and be the focus for the crosshair selection.
final class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The interactive content view: crosshair cursor + click/move/click selection.
final class CrosshairOverlayView: NSView {
    weak var controller: CrosshairSelectionController?
    var windowOrigin: CGPoint = .zero

    private enum Phase {
        case awaitingPress
        case selecting
    }

    private var phase: Phase = .awaitingPress
    private var startPoint: CGPoint = .zero    // AppKit global coords.
    private var currentPoint: CGPoint = .zero

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Keep the crosshair cursor across the whole overlay.
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: Mouse

    // Press to set the start corner, drag to size the selection, release to capture.
    override func mouseDown(with event: NSEvent) {
        startPoint = globalPoint(of: event)
        currentPoint = startPoint
        phase = .selecting
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard phase == .selecting else { return }
        currentPoint = globalPoint(of: event)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard phase == .selecting else { return }
        currentPoint = globalPoint(of: event)
        controller?.finish(rect: selectionRect())
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            controller?.finish(rect: nil)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if phase == .awaitingPress {
            // Faint dim + a hint so it's obvious the mode is armed.
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.12).cgColor)
            ctx.fill(bounds)
            drawHint()
            return
        }
        SelectionRendering.draw(
            in: ctx, bounds: bounds,
            selectionRect: selectionRect(),
            windowOrigin: windowOrigin, dim: true
        )
    }

    private func drawHint() {
        let text = "Drag to select an area · release to capture · Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 12
        let box = CGRect(
            x: bounds.midX - size.width / 2 - padding,
            y: bounds.midY - size.height / 2 - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding
        )
        let path = NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.6).setFill()
        path.fill()
        text.draw(at: CGPoint(x: box.minX + padding, y: box.minY + padding / 2), withAttributes: attributes)
    }

    // MARK: Helpers

    private func globalPoint(of event: NSEvent) -> CGPoint {
        guard let window else { return .zero }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    private func selectionRect() -> CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}
