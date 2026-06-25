import AppKit
import Carbon.HIToolbox

/// The user-configurable trigger that arms a capture gesture.
///
/// A trigger is either a mouse button (default: the middle button) or a keyboard
/// key combined with modifier flags. In both cases the gesture works the same way:
/// press-and-hold to arm, drag past the threshold to start selecting, release to
/// capture.
enum TriggerConfig: Codable, Equatable {
    /// A mouse button identified by its `buttonNumber` (2 == middle button).
    case mouseButton(Int)
    /// A keyboard key identified by its virtual key code, plus modifier flags
    /// stored as the raw value of `NSEvent.ModifierFlags`.
    case keyboard(keyCode: Int, modifiers: UInt)

    static let middleMouseButton = TriggerConfig.mouseButton(2)

    /// Human-readable label shown in the settings UI.
    var displayName: String {
        switch self {
        case .mouseButton(let number):
            switch number {
            case 0: return "Left Mouse Button"
            case 1: return "Right Mouse Button"
            case 2: return "Middle Mouse Button"
            default: return "Mouse Button \(number + 1)"
            }
        case .keyboard(let keyCode, let modifiers):
            let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            return TriggerConfig.modifierString(flags) + TriggerConfig.keyName(for: keyCode)
        }
    }

    /// True when this trigger is driven by a mouse button.
    var isMouse: Bool {
        if case .mouseButton = self { return true }
        return false
    }

    private static func modifierString(_ flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }

    private static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            if let char = TriggerConfig.character(for: keyCode) {
                return char.uppercased()
            }
            return "Key \(keyCode)"
        }
    }

    /// Translates a virtual key code into its current-layout character, if any.
    private static func character(for keyCode: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = UCKeyTranslate(
            keyLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
