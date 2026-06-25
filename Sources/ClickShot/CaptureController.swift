import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Drives the capture gesture state machine and ties together the event tap,
/// the selection overlay, the screen capturer, and the clipboard.
///
/// Gesture lifecycle:
///   idle → (trigger pressed) → armed → (moved past threshold) → dragging
///        → (trigger released) → capture → idle
///
/// For a mouse-button trigger we deliberately *observe* (never swallow) the
/// button events: swallowing the button-down stops the window server from
/// generating drag events and freezes the cursor. We let them flow and just
/// watch them to drive the overlay.
final class CaptureController {
    private enum State {
        case idle
        case armed
        case dragging
    }

    private let eventTap = EventTapManager()
    private let overlay = SelectionOverlayController()
    private let capturer = ScreenCapturer()

    private var state: State = .idle
    private var startPoint: CGPoint = .zero    // AppKit global coords (bottom-left).
    private var currentPoint: CGPoint = .zero

    /// Installs the global event tap. Returns false if Accessibility is missing.
    @discardableResult
    func start() -> Bool {
        eventTap.onEvent = { [weak self] type, event in
            self?.handle(type: type, event: event) ?? false
        }
        return eventTap.start()
    }

    func stop() {
        eventTap.stop()
    }

    private var trigger: TriggerConfig { Preferences.shared.trigger }
    private var threshold: CGFloat { Preferences.shared.dragThreshold }

    // MARK: - Event handling

    /// Returns true to swallow the event.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        // Esc cancels an in-progress gesture (and is swallowed so it doesn't
        // reach other apps).
        if type == .keyDown,
           event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape),
           state != .idle {
            cancelGesture()
            return true
        }

        switch trigger {
        case .mouseButton(let number):
            return handleMouseTrigger(buttonNumber: number, type: type, event: event)
        case .keyboard(let keyCode, let modifiers):
            return handleKeyboardTrigger(keyCode: keyCode, modifiers: modifiers, type: type, event: event)
        }
    }

    // MARK: Mouse-button trigger (observe only — never swallow)

    private func handleMouseTrigger(buttonNumber: Int, type: CGEventType, event: CGEvent) -> Bool {
        let isDown = type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown
        let isUp = type == .leftMouseUp || type == .rightMouseUp || type == .otherMouseUp
        let isDrag = type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged

        if isDown, eventButtonNumber(type: type, event: event) == buttonNumber, state == .idle {
            startPoint = NSEvent.mouseLocation
            currentPoint = startPoint
            state = .armed
            return false
        }

        guard state != .idle else { return false }

        if isDrag {
            updateDrag(to: NSEvent.mouseLocation)
            return false
        }

        if isUp, eventButtonNumber(type: type, event: event) == buttonNumber {
            if state == .dragging { finishCapture() }
            state = .idle
            return false
        }

        return false
    }

    // MARK: Keyboard trigger

    private func handleKeyboardTrigger(keyCode: Int, modifiers: UInt, type: CGEventType, event: CGEvent) -> Bool {
        if type == .keyDown,
           state == .idle,
           event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode),
           matchesModifiers(modifiers, flags: event.flags) {
            startPoint = NSEvent.mouseLocation
            currentPoint = startPoint
            state = .armed
            return true  // Swallow the hotkey so it doesn't type/act elsewhere.
        }

        guard state != .idle else { return false }

        // The mouse button isn't held during a keyboard gesture, so we follow
        // plain pointer movement. Observe but never swallow it.
        if type == .mouseMoved || type == .leftMouseDragged
            || type == .rightMouseDragged || type == .otherMouseDragged {
            updateDrag(to: NSEvent.mouseLocation)
            return false
        }

        if type == .keyUp, event.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode) {
            if state == .dragging { finishCapture() }
            state = .idle
            return true
        }

        return false
    }

    // MARK: - Gesture helpers

    private func updateDrag(to point: CGPoint) {
        currentPoint = point
        if state == .armed {
            let distance = hypot(point.x - startPoint.x, point.y - startPoint.y)
            if distance >= threshold {
                state = .dragging
                overlay.show()
            }
        }
        if state == .dragging {
            overlay.update(selection: selectionRect())
        }
    }

    private func selectionRect() -> CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    private func finishCapture() {
        let rect = selectionRect()
        overlay.hide()
        guard rect.width >= 1, rect.height >= 1 else { return }
        capturer.capture(appKitRect: rect) { image in
            guard let image else {
                NSLog("ClickShot: capture failed")
                return
            }
            ClipboardWriter.write(image)
        }
    }

    private func cancelGesture() {
        overlay.hide()
        state = .idle
    }

    // MARK: - Event parsing

    private func eventButtonNumber(type: CGEventType, event: CGEvent) -> Int {
        switch type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged: return 0
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged: return 1
        default: return Int(event.getIntegerValueField(.mouseEventButtonNumber))
        }
    }

    private func matchesModifiers(_ wanted: UInt, flags: CGEventFlags) -> Bool {
        let wantedFlags = NSEvent.ModifierFlags(rawValue: wanted)
        var actual = NSEvent.ModifierFlags()
        if flags.contains(.maskCommand) { actual.insert(.command) }
        if flags.contains(.maskAlternate) { actual.insert(.option) }
        if flags.contains(.maskControl) { actual.insert(.control) }
        if flags.contains(.maskShift) { actual.insert(.shift) }
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return actual.intersection(relevant) == wantedFlags.intersection(relevant)
    }
}
