import AppKit
import CoreGraphics
import ApplicationServices

/// Helpers for the two TCC permissions ClickShot needs:
/// Accessibility (to install a global event tap) and Screen Recording (to capture).
enum Permissions {
    /// Whether the process is trusted for Accessibility (required for the event tap).
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user for Accessibility access (shows the system dialog once).
    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Whether the app currently has Screen Recording permission.
    static var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Prompts the user for Screen Recording access (shows the system dialog once).
    @discardableResult
    static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
