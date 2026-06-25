import AppKit

/// A small settings window: launch-at-login toggle, trigger recorder, and the
/// status of the two required permissions.
final class SettingsWindowController: NSWindowController {
    private var launchCheckbox: NSButton!
    private var recorder: RecorderButton!
    private var accessibilityRow: PermissionRow!
    private var screenRow: PermissionRow!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
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

        // Trigger
        stack.addArrangedSubview(sectionLabel("Capture trigger"))
        recorder = RecorderButton()
        recorder.onChange = { [weak self] in self?.refresh() }
        stack.addArrangedSubview(recorder)
        stack.addArrangedSubview(hintLabel("Click the button, then press a mouse button or keyboard shortcut. Hold it and drag to select an area; release to copy the screenshot."))

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
        recorder.title = "  " + Preferences.shared.trigger.displayName + "  "
        launchCheckbox.state = LoginItemManager.isEnabled ? .on : .off
        accessibilityRow.setGranted(Permissions.hasAccessibility)
        screenRow.setGranted(Permissions.hasScreenRecording)
    }

    @objc private func toggleLaunch() {
        LoginItemManager.setEnabled(launchCheckbox.state == .on)
        refresh()
    }

    // MARK: - Builders

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

/// A button that records the next mouse button or keyboard shortcut as the trigger.
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
        title = "  Press a key or mouse button…  "

        let mask: NSEvent.EventTypeMask = [
            .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
        ]
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.capture(event)
            return nil  // Swallow while recording.
        }
    }

    private func capture(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            // Esc cancels recording without changing the trigger.
            if event.keyCode == 53 {
                finish()
                return
            }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
            Preferences.shared.trigger = .keyboard(keyCode: Int(event.keyCode), modifiers: modifiers)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            Preferences.shared.trigger = .mouseButton(event.buttonNumber)
        default:
            break
        }
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
