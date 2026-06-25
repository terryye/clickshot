import AppKit

/// Owns the menu-bar status item and its menu.
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let settingsController = SettingsWindowController()
    private var launchAtLoginItem: NSMenuItem?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = StatusBarController.makeMenuBarIcon()
        }

        statusItem.menu = makeMenu()
    }

    /// The "Capture C" mark — an open ring with a crosshair click-target — drawn
    /// as a template image so the menu bar tints it for light/dark automatically.
    /// Mirrors `logo/logo-capture-c.svg` (a 24-unit grid scaled into 18pt).
    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let scale: CGFloat = 18.0 / 24.0          // map the 24-unit SVG grid to 18pt
            let center = NSPoint(x: 12 * scale, y: 12 * scale)
            let radius: CGFloat = 8 * scale

            // Open "C" ring: gap of ±38° centred on the right (3 o'clock).
            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: radius, startAngle: 38, endAngle: 322)
            ring.lineWidth = 2 * scale
            ring.lineCapStyle = .round
            ring.lineJoinStyle = .round

            // Crosshair click-target (a plus spanning ±2.5 units around centre).
            let arm: CGFloat = 2.5 * scale
            let cross = NSBezierPath()
            cross.move(to: NSPoint(x: center.x, y: center.y - arm))
            cross.line(to: NSPoint(x: center.x, y: center.y + arm))
            cross.move(to: NSPoint(x: center.x - arm, y: center.y))
            cross.line(to: NSPoint(x: center.x + arm, y: center.y))
            cross.lineWidth = 2 * scale
            cross.lineCapStyle = .round

            NSColor.black.setStroke()
            ring.stroke()
            cross.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = MenuRefresher.shared
        MenuRefresher.shared.controller = self

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
/*
        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        menu.addItem(launch)
        launchAtLoginItem = launch
*/
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit ClickShot", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    func refreshMenu() {
        launchAtLoginItem?.state = LoginItemManager.isEnabled ? .on : .off
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func toggleLaunchAtLogin() {
        LoginItemManager.setEnabled(!LoginItemManager.isEnabled)
        refreshMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Refreshes the menu's dynamic state (the login-item checkmark) before it opens.
private final class MenuRefresher: NSObject, NSMenuDelegate {
    static let shared = MenuRefresher()
    weak var controller: StatusBarController?

    func menuWillOpen(_ menu: NSMenu) {
        controller?.refreshMenu()
    }
}
