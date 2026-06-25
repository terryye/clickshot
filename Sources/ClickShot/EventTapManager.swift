import AppKit
import CoreGraphics

/// Installs a global `CGEvent` tap and forwards mouse/keyboard events to a
/// delegate, which decides whether each event should be swallowed.
final class EventTapManager {
    /// The delegate returns `true` to consume (swallow) an event so it never
    /// reaches other applications.
    var onEvent: ((CGEventType, CGEvent) -> Bool)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let eventMask: CGEventMask = {
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .mouseMoved,
            .keyDown, .keyUp,
        ]
        return types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    }()

    /// Creates and enables the tap. Requires Accessibility permission; returns
    /// `false` if the tap could not be created.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handle(type: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: EventTapManager.eventMask,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("ClickShot: failed to create event tap (Accessibility permission?)")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables the tap if our callback is too slow or on certain
        // user-switch events. Re-enable it and pass the event through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let consume = onEvent?(type, event) ?? false
        return consume ? nil : Unmanaged.passUnretained(event)
    }
}
