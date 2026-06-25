import Foundation

/// Persists user settings in `UserDefaults`.
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let middleButtonEnabled = "middleButtonEnabled"
        static let keyboardShortcut = "keyboardShortcut"
        static let dragThreshold = "dragThreshold"
        static let macOSOverlayStyle = "macOSOverlayStyle"
    }

    private init() {}

    /// Whether the middle mouse button acts as a capture trigger. Default: on.
    var middleButtonEnabled: Bool {
        get { defaults.object(forKey: Key.middleButtonEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.middleButtonEnabled) }
    }

    /// The configured keyboard shortcut trigger, or `nil` if none is set.
    var keyboardShortcut: KeyboardShortcut? {
        get {
            guard let data = defaults.data(forKey: Key.keyboardShortcut) else { return nil }
            return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.keyboardShortcut)
            } else {
                defaults.removeObject(forKey: Key.keyboardShortcut)
            }
        }
    }

    /// Minimum pointer travel (in points) before a press becomes a capture drag.
    var dragThreshold: CGFloat {
        get {
            let value = defaults.double(forKey: Key.dragThreshold)
            return value > 0 ? value : 5
        }
        set { defaults.set(newValue, forKey: Key.dragThreshold) }
    }

    /// When true, the overlay matches the macOS screenshot look: only the selected
    /// area is tinted, leaving the rest of the screen undimmed. When false
    /// (default), the surroundings are dimmed and the selection is a clear hole.
    var macOSOverlayStyle: Bool {
        get { defaults.bool(forKey: Key.macOSOverlayStyle) }
        set { defaults.set(newValue, forKey: Key.macOSOverlayStyle) }
    }

    /// The overlay style derived from `macOSOverlayStyle`.
    var overlayStyle: SelectionRendering.OverlayStyle {
        macOSOverlayStyle ? .highlightSelection : .dimSurroundings
    }
}
