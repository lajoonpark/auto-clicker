#if canImport(AppKit)
import AppKit

@MainActor
final class AutoClickerViewController: NSViewController {
    private static let defaultIntervalMilliseconds = 100

    var onToggleRequested: ((AutoClickConfiguration) -> Void)?
    var onHotkeyChanged: ((HotkeyShortcut) -> Void)?

    private let targetSelector = NSSegmentedControl(labels: ["Left Click", "Right Click", "Keyboard Combo"], trackingMode: .selectOne, target: nil, action: nil)
    private let comboField = KeyCaptureField(style: .combo(maximumKeys: InputConstants.maximumComboKeys), placeholder: "Click to record key combo")
    private let intervalModeSelector = NSSegmentedControl(labels: ["Fixed", "Random Range"], trackingMode: .selectOne, target: nil, action: nil)
    private let intervalSlider = NSSlider(value: Double(AutoClickerViewController.defaultIntervalMilliseconds), minValue: 10, maxValue: 10_000, target: nil, action: nil)
    private let intervalField = NSTextField(string: String(AutoClickerViewController.defaultIntervalMilliseconds))
    private let randomMinField = NSTextField(string: "100")
    private let randomMaxField = NSTextField(string: "250")
    private let repeatSelector = NSSegmentedControl(labels: ["Until Stopped", "Fixed Count"], trackingMode: .selectOne, target: nil, action: nil)
    private let repeatCountField = NSTextField(string: "100")
    private let hotkeyField = KeyCaptureField(style: .hotkey, placeholder: "Click and press a hotkey")
    private let startButton = ModernButton(title: "Start", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: String(format: "Ready · %.1f actions/s", AutoClickerViewController.actionsPerSecond(interval: AutoClickerViewController.defaultIntervalMilliseconds)))
    private var currentCombo = InputConstants.defaultCombo

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        targetSelector.selectedSegment = 0
        repeatSelector.selectedSegment = 0
        intervalModeSelector.selectedSegment = 0
        repeatCountField.isEnabled = false
        targetSelector.target = self
        targetSelector.action = #selector(targetChanged)
        comboField.onComboCaptured = { [weak self] combo in self?.currentCombo = combo }
        comboField.setCombo(currentCombo)
        intervalModeSelector.target = self
        intervalModeSelector.action = #selector(intervalModeChanged)
        intervalSlider.target = self
        intervalSlider.action = #selector(sliderChanged)
        intervalField.target = self
        intervalField.action = #selector(intervalCommitted)
        randomMinField.target = self
        randomMinField.action = #selector(randomRangeCommitted)
        randomMaxField.target = self
        randomMaxField.action = #selector(randomRangeCommitted)
        repeatSelector.target = self
        repeatSelector.action = #selector(repeatModeChanged)
        hotkeyField.onHotkeyCaptured = { [weak self] shortcut in self?.onHotkeyChanged?(shortcut) }
        startButton.target = self
        startButton.action = #selector(toggleRequested)
        startButton.isProminent = true
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        layout()
        intervalModeChanged()
        targetChanged()
    }

    func setHotkey(_ hotkey: HotkeyShortcut) {
        hotkeyField.setShortcut(hotkey)
    }

    func setRunning(_ isRunning: Bool) {
        startButton.title = isRunning ? "Stop" : "Start"
        startButton.isProminent = !isRunning
        statusLabel.stringValue = Self.statusText(isRunning: isRunning, interval: currentIntervalSetting())
    }

    func currentConfiguration() -> AutoClickConfiguration {
        let target: RepeatTarget
        switch targetSelector.selectedSegment {
        case 1:
            target = .mouse(.right)
        case 2:
            target = .keyCombo(currentCombo)
        default:
            target = .mouse(.left)
        }
        let interval = currentIntervalSetting()
        let mode: AutoClickRepeatMode = repeatSelector.selectedSegment == 0 ? .untilStopped : .count(max(repeatCountField.integerValue, 1))
        return AutoClickConfiguration(target: target, interval: interval, repeatMode: mode)
    }

    private func layout() {
        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        [
            makeTargetSection(),
            makeIntervalSection(),
            makeRepeatSection(),
            makeSection(title: "Start / Stop Hotkey", contentView: hotkeyField),
            statusLabel,
            startButton
        ].forEach { content.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        startButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
    }

    private func makeTargetSection() -> NSView {
        let stack = NSStackView(views: [targetSelector, comboField])
        stack.orientation = .vertical
        stack.spacing = 8
        return makeSection(title: "Repeated Action", contentView: stack)
    }

    private func makeIntervalSection() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 8
        let label = NSTextField(labelWithString: "Action Interval (ms)")
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        let row = NSStackView(views: [intervalSlider, intervalField])
        row.orientation = .horizontal
        row.spacing = 10
        let randomRow = NSStackView(views: [randomMinField, randomMaxField])
        randomRow.orientation = .horizontal
        randomRow.spacing = 10
        intervalField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        randomMinField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        randomMaxField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        container.addArrangedSubview(label)
        container.addArrangedSubview(intervalModeSelector)
        container.addArrangedSubview(row)
        container.addArrangedSubview(randomRow)
        return wrap(container)
    }

    private func makeRepeatSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        let label = NSTextField(labelWithString: "Repeat Mode")
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        let row = NSStackView(views: [repeatSelector, repeatCountField])
        row.orientation = .horizontal
        row.spacing = 10
        repeatCountField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(row)
        return wrap(stack)
    }

    private func makeSection(title: String, contentView: NSView) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(contentView)
        return wrap(stack)
    }

    private func wrap(_ content: NSView) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        return container
    }

    @objc private func sliderChanged() {
        intervalField.stringValue = String(Int(intervalSlider.doubleValue))
        setRunning(false)
    }

    @objc private func intervalCommitted() {
        let clamped = min(max(intervalField.integerValue, 10), 10_000)
        intervalField.stringValue = String(clamped)
        intervalSlider.doubleValue = Double(clamped)
        setRunning(false)
    }

    @objc private func randomRangeCommitted() {
        let minValue = min(max(randomMinField.integerValue, 10), 10_000)
        let maxValue = min(max(randomMaxField.integerValue, 10), 10_000)
        randomMinField.stringValue = String(min(minValue, maxValue))
        randomMaxField.stringValue = String(max(minValue, maxValue))
        setRunning(false)
    }

    @objc private func repeatModeChanged() {
        repeatCountField.isEnabled = repeatSelector.selectedSegment == 1
    }

    @objc private func intervalModeChanged() {
        let isRandom = intervalModeSelector.selectedSegment == 1
        intervalSlider.isEnabled = !isRandom
        intervalField.isEnabled = !isRandom
        intervalSlider.alphaValue = isRandom ? 0.45 : 1
        intervalField.alphaValue = isRandom ? 0.45 : 1
        randomMinField.isEnabled = isRandom
        randomMaxField.isEnabled = isRandom
        randomMinField.alphaValue = isRandom ? 1 : 0.45
        randomMaxField.alphaValue = isRandom ? 1 : 0.45
        setRunning(false)
    }

    @objc private func targetChanged() {
        let comboEnabled = targetSelector.selectedSegment == 2
        comboField.isEnabled = comboEnabled
        comboField.alphaValue = comboEnabled ? 1 : 0.45
    }

    @objc private func toggleRequested() {
        onToggleRequested?(currentConfiguration())
    }

    private func currentIntervalSetting() -> AutoClickInterval {
        if intervalModeSelector.selectedSegment == 1 {
            let minimum = min(max(randomMinField.integerValue, 10), 10_000)
            let maximum = min(max(randomMaxField.integerValue, 10), 10_000)
            return .randomRange(minMilliseconds: min(minimum, maximum), maxMilliseconds: max(minimum, maximum))
        }
        return .fixed(milliseconds: max(Int(intervalField.integerValue), 10))
    }

    private static func actionsPerSecond(interval: Int) -> Double {
        1000.0 / Double(interval)
    }

    private static func statusText(isRunning: Bool, interval: AutoClickInterval) -> String {
        let prefix = isRunning ? "Running" : "Ready"
        switch interval {
        case let .fixed(milliseconds):
            let rate = actionsPerSecond(interval: milliseconds)
            return String(format: "\(prefix) · %.1f actions/s", rate)
        case let .randomRange(minMilliseconds, maxMilliseconds):
            let fast = actionsPerSecond(interval: max(min(minMilliseconds, maxMilliseconds), 10))
            let slow = actionsPerSecond(interval: max(max(minMilliseconds, maxMilliseconds), 10))
            return String(format: "\(prefix) · %.1f-%.1f actions/s", slow, fast)
        }
    }
}
#endif
