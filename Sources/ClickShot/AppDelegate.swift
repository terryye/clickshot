import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private let captureController = CaptureController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar accessory app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)

        statusBar = StatusBarController()

        // Screen Recording can be requested without blocking; do it early.
        if !Permissions.hasScreenRecording {
            Permissions.requestScreenRecording()
        }

        startCaptureOrPrompt()
    }

    /// Starts the global event tap, prompting for Accessibility if it's missing.
    private func startCaptureOrPrompt() {
        if Permissions.hasAccessibility {
            captureController.start()
        } else {
            Permissions.requestAccessibility()
            // Poll for the grant, then start without requiring a relaunch.
            pollForAccessibility()
        }
    }

    private func pollForAccessibility() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if Permissions.hasAccessibility {
                self.captureController.start()
            } else {
                self.pollForAccessibility()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureController.stop()
    }
}
