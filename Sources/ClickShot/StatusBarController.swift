import AppKit

/// Owns the menu-bar status item and its menu.
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let settingsController = SettingsWindowController()
    private var launchAtLoginItem: NSMenuItem?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "ClickShot")
            button.image?.isTemplate = true
        }

        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = MenuRefresher.shared
        MenuRefresher.shared.controller = self

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        menu.addItem(launch)
        launchAtLoginItem = launch

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
