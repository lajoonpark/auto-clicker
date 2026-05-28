#if canImport(AppKit)
import AppKit

@MainActor
final class KeyHolderViewController: NSViewController {
    var onToggleRequested: ((HoldTarget) -> Void)?
    var onStartRequested: ((HoldTarget) -> Void)?
    var onStopRequested: (() -> Void)?
    var onHotkeyChanged: ((HotkeyShortcut) -> Void)?

    private let targetSelector = NSSegmentedControl(labels: ["Keyboard Combo", "Left Mouse", "Right Mouse"], trackingMode: .selectOne, target: nil, action: nil)
    private let comboField = KeyCaptureField(style: .combo(maximumKeys: 4), placeholder: "Click, press keys, then Return")
    private let modeSelector = NSSegmentedControl(labels: ["Toggle", "While Pressed"], trackingMode: .selectOne, target: nil, action: nil)
    private let hotkeyField = KeyCaptureField(style: .hotkey, placeholder: "Click and press a hotkey")
    private let startButton = ModernButton(title: "Start Holding", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Not holding")
    private var currentCombo = KeyCombo(keyCodes: [8], modifiers: [.command])

    override func loadView() {
        view = NSView()
        targetSelector.selectedSegment = 0
        modeSelector.selectedSegment = 0
        targetSelector.target = self
        targetSelector.action = #selector(targetChanged)
        comboField.onComboCaptured = { [weak self] combo in self?.currentCombo = combo }
        hotkeyField.onHotkeyCaptured = { [weak self] shortcut in self?.onHotkeyChanged?(shortcut) }
        startButton.target = self
        startButton.action = #selector(togglePressed)
        startButton.isProminent = true
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        layout()
    }

    var holdMode: KeyHolderMode {
        modeSelector.selectedSegment == 0 ? .toggle : .whilePressed
    }

    func currentTarget() -> HoldTarget {
        switch targetSelector.selectedSegment {
        case 1: .mouse(.left)
        case 2: .mouse(.right)
        default: .keyCombo(currentCombo)
        }
    }

    func setHotkey(_ hotkey: HotkeyShortcut) {
        hotkeyField.setShortcut(hotkey)
    }

    func setHolding(_ isHolding: Bool) {
        startButton.title = isHolding ? "Release" : "Start Holding"
        statusLabel.stringValue = isHolding ? "Holding input" : "Not holding"
    }

    private func layout() {
        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        [
            makeSection(title: "Hold Target", contentView: targetSelector),
            makeSection(title: "Keyboard Combo", contentView: comboField),
            makeSection(title: "Hotkey Mode", contentView: modeSelector),
            makeSection(title: "Hold Trigger Hotkey", contentView: hotkeyField),
            statusLabel,
            startButton
        ].forEach { content.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        comboField.setCombo(currentCombo)
        startButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
    }

    private func makeSection(title: String, contentView: NSView) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(contentView)
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        return container
    }

    @objc private func targetChanged() {
        comboField.isEnabled = targetSelector.selectedSegment == 0
        comboField.alphaValue = targetSelector.selectedSegment == 0 ? 1 : 0.4
    }

    @objc private func togglePressed() {
        switch holdMode {
        case .toggle:
            onToggleRequested?(currentTarget())
        case .whilePressed:
            onStartRequested?(currentTarget())
        }
    }
}
#endif
