import AppKit

/// A small settings window: launch-at-login toggle, trigger recorder, and the
/// status of the two required permissions.
final class SettingsWindowController: NSWindowController {
    private var launchCheckbox: NSButton!
    private var overlayStyleCheckbox: NSButton!
    private var middleButtonCheckbox: NSButton!
    private var recorder: RecorderButton!
    private var accessibilityRow: PermissionRow!
    private var screenRow: PermissionRow!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 490),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClickShot"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildContent()
    }

    func show() {
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        guard let window else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // App identity header (icon + name + version) — the in-app home for the
        // app icon, since an LSUIElement app has no Dock presence.
        stack.addArrangedSubview(appHeader())
        stack.addArrangedSubview(separator())

        // Triggers — the middle button and a keyboard shortcut are independent;
        // either or both can be active.
        stack.addArrangedSubview(sectionLabel("Capture triggers"))

        middleButtonCheckbox = NSButton(checkboxWithTitle: "Middle mouse button", target: self, action: #selector(toggleMiddleButton))
        stack.addArrangedSubview(middleButtonCheckbox)
        stack.addArrangedSubview(hintLabel("Hold the middle button and drag to select an area; release to copy."))

        recorder = RecorderButton()
        recorder.onChange = { [weak self] in self?.refresh() }
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearShortcut))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        let shortcutRow = NSStackView(views: [
            NSTextField(labelWithString: "Keyboard shortcut:"), recorder, clearButton,
        ])
        shortcutRow.orientation = .horizontal
        shortcutRow.spacing = 8
        shortcutRow.alignment = .centerY
        stack.addArrangedSubview(shortcutRow)
        stack.addArrangedSubview(hintLabel("Tap the shortcut, then hold the left button and drag to select; release to copy."))

        stack.addArrangedSubview(separator())

        // Overlay appearance
        stack.addArrangedSubview(sectionLabel("Overlay"))
        overlayStyleCheckbox = NSButton(checkboxWithTitle: "macOS-style selection overlay", target: self, action: #selector(toggleOverlayStyle))
        stack.addArrangedSubview(overlayStyleCheckbox)
        stack.addArrangedSubview(hintLabel("Tint only the selected area instead of dimming the rest of the screen."))

        stack.addArrangedSubview(separator())

        // Launch at login
        launchCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunch))
        stack.addArrangedSubview(launchCheckbox)

        stack.addArrangedSubview(separator())

        // Permissions
        stack.addArrangedSubview(sectionLabel("Permissions"))
        accessibilityRow = PermissionRow(title: "Accessibility") { Permissions.openAccessibilitySettings() }
        screenRow = PermissionRow(title: "Screen Recording") { Permissions.openScreenRecordingSettings() }
        stack.addArrangedSubview(accessibilityRow)
        stack.addArrangedSubview(screenRow)

        let content = NSView()
        content.addSubview(stack)
        window.contentView = content

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
        ])
    }

    private func refresh() {
        let shortcut = Preferences.shared.keyboardShortcut
        recorder.title = "  " + (shortcut?.displayName ?? "Not set") + "  "
        middleButtonCheckbox.state = Preferences.shared.middleButtonEnabled ? .on : .off
        launchCheckbox.state = LoginItemManager.isEnabled ? .on : .off
        overlayStyleCheckbox.state = Preferences.shared.macOSOverlayStyle ? .on : .off
        accessibilityRow.setGranted(Permissions.hasAccessibility)
        screenRow.setGranted(Permissions.hasScreenRecording)
    }

    @objc private func toggleMiddleButton() {
        Preferences.shared.middleButtonEnabled = middleButtonCheckbox.state == .on
    }

    @objc private func clearShortcut() {
        Preferences.shared.keyboardShortcut = nil
        refresh()
    }

    @objc private func toggleLaunch() {
        LoginItemManager.setEnabled(launchCheckbox.state == .on)
        refresh()
    }

    @objc private func toggleOverlayStyle() {
        Preferences.shared.macOSOverlayStyle = overlayStyleCheckbox.state == .on
    }

    // MARK: - Builders

    private func appHeader() -> NSStackView {
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage   // resolves CFBundleIconFile (AppIcon.icns)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 56).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let name = NSTextField(labelWithString: "ClickShot")
        name.font = .systemFont(ofSize: 17, weight: .semibold)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let versionLabel = NSTextField(labelWithString: version.isEmpty ? "" : "Version \(version)")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor

        let titleStack = NSStackView(views: [name, versionLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        let header = NSStackView(views: [icon, titleStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        return header
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func hintLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 340
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 340).isActive = true
        return box
    }
}

/// A button that records the next keyboard shortcut as the keyboard trigger.
final class RecorderButton: NSButton {
    var onChange: (() -> Void)?
    private var monitor: Any?
    private var recording = false

    convenience init() {
        self.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
    }

    deinit { removeMonitor() }

    @objc private func beginRecording() {
        guard !recording else { return }
        recording = true
        title = "  Press a shortcut…  "

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.capture(event)
            return nil  // Swallow while recording.
        }
    }

    private func capture(_ event: NSEvent) {
        // Esc cancels recording without changing the shortcut.
        if event.keyCode == 53 {
            finish()
            return
        }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
        Preferences.shared.keyboardShortcut = KeyboardShortcut(keyCode: Int(event.keyCode), modifiers: modifiers)
        finish()
    }

    private func finish() {
        recording = false
        removeMonitor()
        onChange?()
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

/// A row showing a permission's name, its granted state, and an "Open Settings" button.
final class PermissionRow: NSStackView {
    private let statusLabel = NSTextField(labelWithString: "")
    private let openAction: () -> Void

    init(title: String, openAction: @escaping () -> Void) {
        self.openAction = openAction
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 8
        alignment = .centerY

        let name = NSTextField(labelWithString: title)
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let open = NSButton(title: "Open Settings", target: self, action: #selector(openSettings))
        open.bezelStyle = .rounded
        open.controlSize = .small

        addArrangedSubview(statusLabel)
        addArrangedSubview(name)
        addArrangedSubview(open)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setGranted(_ granted: Bool) {
        statusLabel.stringValue = granted ? "✅" : "⚠️"
    }

    @objc private func openSettings() {
        openAction()
    }
}
