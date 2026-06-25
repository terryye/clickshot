import AppKit
import Carbon.HIToolbox

/// Interactive crosshair selection used by keyboard triggers, mirroring the macOS
/// screenshot flow: the cursor becomes a crosshair, pressing sets the start corner,
/// dragging sizes the selection, and releasing captures.
///
/// One overlay window is created **per display** (a single union-spanning window is
/// clipped to one display when "Displays have separate Spaces" is on — the macOS
/// default; see `TECH_DECISIONS.md`). The selection state is owned by the controller
/// and shared across all views, so a drag that begins on one monitor and crosses
/// onto another tracks correctly: macOS keeps delivering the drag to the window that
/// received the mouse-down, which converts to global coordinates regardless of which
/// display the pointer is over.
final class CrosshairSelectionController {
    private var windows: [NSWindow] = []
    private var views: [CrosshairOverlayView] = []
    private var onComplete: ((CGRect?) -> Void)?

    enum Phase {
        case awaitingPress
        case selecting
    }

    private(set) var phase: Phase = .awaitingPress
    private var startPoint: CGPoint = .zero    // AppKit global coords.
    private var currentPoint: CGPoint = .zero

    var isActive: Bool { !windows.isEmpty }

    /// Presents the crosshair overlay on every display. `completion` receives the
    /// selected rect in AppKit global coordinates, or `nil` if cancelled.
    func begin(completion: @escaping (CGRect?) -> Void) {
        guard windows.isEmpty else { return }
        onComplete = completion
        phase = .awaitingPress

        NSApp.activate(ignoringOtherApps: true)

        let mainFrame = NSScreen.main?.frame
        for screen in NSScreen.screens {
            let frame = screen.frame
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
            v.screenFrame = frame
            v.controller = self
            win.contentView = v

            // The main screen's window is the key window (it owns Esc / keyDown);
            // the rest are just ordered front so they render on their displays.
            // Compare frames — NSScreen identity equality is unreliable.
            if frame == mainFrame {
                win.makeKeyAndOrderFront(nil)
                win.makeFirstResponder(v)
            } else {
                win.orderFrontRegardless()
            }

            windows.append(win)
            views.append(v)
        }

        // Guarantee a key window (owns Esc) even if no frame matched the main screen.
        if NSApp.keyWindow == nil, let first = windows.first {
            first.makeKeyAndOrderFront(nil)
            first.makeFirstResponder(first.contentView)
        }

        NSCursor.crosshair.push()
    }

    // MARK: - Selection state (driven by whichever view has the mouse)

    /// The current selection in AppKit global coordinates.
    func selectionRect() -> CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    func pressed(at point: CGPoint) {
        startPoint = point
        currentPoint = point
        phase = .selecting
        redrawAll()
    }

    func dragged(to point: CGPoint) {
        guard phase == .selecting else { return }
        currentPoint = point
        redrawAll()
    }

    func released(at point: CGPoint) {
        guard phase == .selecting else { return }
        currentPoint = point
        finish(rect: selectionRect())
    }

    func cancel() {
        finish(rect: nil)
    }

    /// The display the size label should be drawn on (the capture target).
    func labelScreen() -> NSScreen? {
        SelectionRendering.targetScreen(for: selectionRect())
    }

    private func redrawAll() {
        views.forEach { $0.needsDisplay = true }
    }

    /// Called when the user finishes (release) or cancels (Esc).
    private func finish(rect: CGRect?) {
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        views.removeAll()
        phase = .awaitingPress
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

/// The interactive content view for one display: crosshair cursor + click/move/
/// click selection. Selection state lives in the controller and is shared across
/// every display's view.
final class CrosshairOverlayView: NSView {
    weak var controller: CrosshairSelectionController?
    var windowOrigin: CGPoint = .zero
    /// This view's screen frame in global coordinates (used to identify the display
    /// owning the selection without relying on `NSScreen` identity).
    var screenFrame: CGRect = .zero

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // A tracking area covering the whole overlay keeps the crosshair cursor in
    // place (cursor rects alone are unreliable on a borderless window). Because it
    // is `.activeAlways` it fires even when this display's window isn't key, so the
    // crosshair persists on every monitor.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    // MARK: Mouse

    // Press to set the start corner, drag to size the selection, release to capture.
    override func mouseDown(with event: NSEvent) {
        controller?.pressed(at: globalPoint(of: event))
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.crosshair.set()
        controller?.dragged(to: globalPoint(of: event))
    }

    override func mouseUp(with event: NSEvent) {
        controller?.released(at: globalPoint(of: event))
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            controller?.cancel()
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let controller else { return }
        let style = Preferences.shared.overlayStyle

        // The window must have non-transparent pixels everywhere or mouse-downs (and
        // cursor updates) pass through fully clear regions. The dim style already
        // fills the whole window; the macOS style would otherwise be clear, so paint
        // an imperceptible base layer to keep the overlay interactive everywhere.
        if style == .highlightSelection {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.01).cgColor)
            ctx.fill(bounds)
        }

        if controller.phase == .awaitingPress {
            if style == .dimSurroundings {
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.12).cgColor)
                ctx.fill(bounds)
            }
            drawHint()
            return
        }
        SelectionRendering.draw(
            in: ctx, bounds: bounds,
            selectionRect: controller.selectionRect(),
            windowOrigin: windowOrigin,
            style: style,
            drawsLabel: screenFrame == controller.labelScreen()?.frame
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
}
