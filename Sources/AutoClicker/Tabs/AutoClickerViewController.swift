#if canImport(AppKit)
import AppKit

@MainActor
final class AutoClickerViewController: NSViewController {
    var onToggleRequested: ((AutoClickConfiguration) -> Void)?
    var onHotkeyChanged: ((HotkeyShortcut) -> Void)?

    private let buttonSelector = NSSegmentedControl(labels: ["Left Click", "Right Click"], trackingMode: .selectOne, target: nil, action: nil)
    private let intervalModeSelector = NSSegmentedControl(labels: ["Fixed", "Random Range"], trackingMode: .selectOne, target: nil, action: nil)
    private let intervalSlider = NSSlider(value: 100, minValue: 10, maxValue: 10_000, target: nil, action: nil)
    private let intervalField = NSTextField(string: "100")
    private let minimumIntervalField = NSTextField(string: "10")
    private let maximumIntervalField = NSTextField(string: "50")
    private let repeatSelector = NSSegmentedControl(labels: ["Until Stopped", "Fixed Count"], trackingMode: .selectOne, target: nil, action: nil)
    private let repeatCountField = NSTextField(string: "100")
    private let hotkeyField = KeyCaptureField(style: .hotkey, placeholder: "Click and press a hotkey")
    private let startButton = ModernButton(title: "Start", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Ready · 10.0 CPS")

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        buttonSelector.selectedSegment = 0
        intervalModeSelector.selectedSegment = 0
        repeatSelector.selectedSegment = 0
        repeatCountField.isEnabled = false
        minimumIntervalField.isEnabled = false
        maximumIntervalField.isEnabled = false
        intervalSlider.target = self
        intervalSlider.action = #selector(sliderChanged)
        intervalField.target = self
        intervalField.action = #selector(intervalCommitted)
        intervalModeSelector.target = self
        intervalModeSelector.action = #selector(intervalModeChanged)
        minimumIntervalField.target = self
        minimumIntervalField.action = #selector(randomIntervalCommitted)
        maximumIntervalField.target = self
        maximumIntervalField.action = #selector(randomIntervalCommitted)
        repeatSelector.target = self
        repeatSelector.action = #selector(repeatModeChanged)
        hotkeyField.onHotkeyCaptured = { [weak self] shortcut in self?.onHotkeyChanged?(shortcut) }
        startButton.target = self
        startButton.action = #selector(toggleRequested)
        startButton.isProminent = true
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        layout()
    }

    func setHotkey(_ hotkey: HotkeyShortcut) {
        hotkeyField.setShortcut(hotkey)
    }

    func setRunning(_ isRunning: Bool) {
        startButton.title = isRunning ? "Stop" : "Start"
        startButton.isProminent = !isRunning
        let cps = 1000.0 / Double(currentConfiguration().minimumIntervalMilliseconds)
        statusLabel.stringValue = isRunning ? String(format: "Running · %.1f CPS", cps) : String(format: "Ready · %.1f CPS", cps)
    }

    func currentConfiguration() -> AutoClickConfiguration {
        let button: MouseButton = buttonSelector.selectedSegment == 0 ? .left : .right
        let intervalMode: AutoClickIntervalMode
        if intervalModeSelector.selectedSegment == 0 {
            let interval = max(Int(intervalField.integerValue), 10)
            intervalMode = .fixed(interval)
        } else {
            let minimum = max(Int(minimumIntervalField.integerValue), 10)
            let maximum = max(Int(maximumIntervalField.integerValue), minimum)
            intervalMode = .random(minMilliseconds: minimum, maxMilliseconds: maximum)
        }
        let mode: AutoClickRepeatMode = repeatSelector.selectedSegment == 0 ? .untilStopped : .count(max(repeatCountField.integerValue, 1))
        return AutoClickConfiguration(button: button, intervalMode: intervalMode, repeatMode: mode)
    }

    private func layout() {
        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        [
            makeSection(title: "Click Button", contentView: buttonSelector),
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

    private func makeIntervalSection() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 8
        let label = NSTextField(labelWithString: "Click Interval (ms)")
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        let modeRow = NSStackView(views: [intervalModeSelector])
        modeRow.orientation = .horizontal
        let row = NSStackView(views: [intervalSlider, intervalField])
        row.orientation = .horizontal
        row.spacing = 10
        intervalField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        minimumIntervalField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        maximumIntervalField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let randomRow = NSStackView(views: [
            NSTextField(labelWithString: "Min"),
            minimumIntervalField,
            NSTextField(labelWithString: "Max"),
            maximumIntervalField
        ])
        randomRow.orientation = .horizontal
        randomRow.spacing = 8
        randomRow.alignment = .centerY
        container.addArrangedSubview(label)
        container.addArrangedSubview(modeRow)
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

    @objc private func intervalModeChanged() {
        let isFixed = intervalModeSelector.selectedSegment == 0
        intervalSlider.isEnabled = isFixed
        intervalField.isEnabled = isFixed
        minimumIntervalField.isEnabled = !isFixed
        maximumIntervalField.isEnabled = !isFixed
        randomIntervalCommitted()
        setRunning(false)
    }

    @objc private func randomIntervalCommitted() {
        let minimum = max(minimumIntervalField.integerValue, 10)
        let maximum = max(maximumIntervalField.integerValue, minimum)
        minimumIntervalField.stringValue = String(minimum)
        maximumIntervalField.stringValue = String(maximum)
        setRunning(false)
    }

    @objc private func repeatModeChanged() {
        repeatCountField.isEnabled = repeatSelector.selectedSegment == 1
    }

    @objc private func toggleRequested() {
        onToggleRequested?(currentConfiguration())
    }
}
#endif

private extension AutoClickConfiguration {
    var minimumIntervalMilliseconds: Int {
        switch intervalMode {
        case let .fixed(value):
            return max(value, 10)
        case let .random(minMilliseconds, _):
            return max(minMilliseconds, 10)
        }
    }
}
