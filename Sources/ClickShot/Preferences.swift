import Foundation

/// Persists user settings in `UserDefaults` and broadcasts changes so live
/// components (such as the event tap) can react.
final class Preferences {
    static let shared = Preferences()

    /// Posted whenever the trigger configuration changes.
    static let triggerDidChange = Notification.Name("ClickShot.triggerDidChange")

    private let defaults = UserDefaults.standard

    private enum Key {
        static let trigger = "trigger"
        static let dragThreshold = "dragThreshold"
    }

    private init() {}

    /// The configured capture trigger. Defaults to the middle mouse button.
    var trigger: TriggerConfig {
        get {
            guard let data = defaults.data(forKey: Key.trigger),
                  let decoded = try? JSONDecoder().decode(TriggerConfig.self, from: data)
            else { return .middleMouseButton }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.trigger)
            }
            NotificationCenter.default.post(name: Preferences.triggerDidChange, object: nil)
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
}
