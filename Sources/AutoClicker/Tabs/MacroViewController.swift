#if canImport(AppKit)
import AppKit

@MainActor
final class MacroViewController: NSViewController {
    var onDocumentChanged: ((MacroDocument) -> Void)?
    var onSaveRequested: (() -> Void)?
    var onNewRequested: (() -> Void)?
    var onSelectionChanged: ((UUID) -> Void)?
    var onPlaybackToggle: ((MacroLoopMode, Double) -> Void)?
    var onRecordingToggle: ((Bool) -> Void)?
    var onHotkeyChanged: ((HotkeyShortcut) -> Void)?
    var mouseLocationProvider: (() -> ScreenPoint)?

    private let nameField = NSTextField(string: "Untitled Macro")
    private let macroPicker = NSPopUpButton()
    private let newButton = ModernButton(title: "New Macro", target: nil, action: nil)
    private let saveButton = ModernButton(title: "Save Macro", target: nil, action: nil)
    private let actionStack = NSStackView()
    private let addLeftClickButton = ModernButton(title: "+ Left Click", target: nil, action: nil)
    private let addRightClickButton = ModernButton(title: "+ Right Click", target: nil, action: nil)
    private let comboField = KeyCaptureField(style: .combo(maximumKeys: 4), placeholder: "Record combo then Return")
    private let addComboButton = ModernButton(title: "+ Add Combo", target: nil, action: nil)
    private let pauseField = NSTextField(string: "250")
    private let addPauseButton = ModernButton(title: "+ Add Pause", target: nil, action: nil)
    private let loopField = NSTextField(string: "1")
    private let untilStoppedButton = NSButton(checkboxWithTitle: "Until stopped", target: nil, action: nil)
    private let speedSelector = NSPopUpButton()
    private let recordButton = ModernButton(title: "Record", target: nil, action: nil)
    private let playButton = ModernButton(title: "Play", target: nil, action: nil)
    private let hotkeyField = KeyCaptureField(style: .hotkey, placeholder: "Click and press a hotkey")
    private let statusLabel = NSTextField(labelWithString: "Build and save macros independently.")

    private var currentDocument = MacroDocument(name: "Untitled Macro")
    private var savedMacros: [MacroDocument] = []
    private var pendingCombo = KeyCombo(keyCodes: [8], modifiers: [.command])
    private var isRecording = false

    override func loadView() {
        view = NSView()
        comboField.onComboCaptured = { [weak self] combo in self?.pendingCombo = combo }
        comboField.setCombo(pendingCombo)
        hotkeyField.onHotkeyCaptured = { [weak self] shortcut in self?.onHotkeyChanged?(shortcut) }
        nameField.target = self
        nameField.action = #selector(nameChanged)
        macroPicker.target = self
        macroPicker.action = #selector(selectionChanged)
        newButton.target = self
        newButton.action = #selector(newMacro)
        saveButton.target = self
        saveButton.action = #selector(saveMacro)
        addLeftClickButton.target = self
        addLeftClickButton.action = #selector(addLeftClick)
        addRightClickButton.target = self
        addRightClickButton.action = #selector(addRightClick)
        addComboButton.target = self
        addComboButton.action = #selector(addCombo)
        addPauseButton.target = self
        addPauseButton.action = #selector(addPause)
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)
        playButton.target = self
        playButton.action = #selector(togglePlayback)
        recordButton.isProminent = false
        playButton.isProminent = true
        speedSelector.addItems(withTitles: ["0.25×", "0.5×", "1×", "2×", "4×"])
        speedSelector.selectItem(withTitle: "1×")
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        buildLayout()
    }

    func setDocument(_ document: MacroDocument) {
        currentDocument = document
        nameField.stringValue = document.name
        refreshActions()
        refreshPickerSelection()
    }

    func setMacros(_ macros: [MacroDocument]) {
        savedMacros = macros
        macroPicker.removeAllItems()
        macroPicker.addItems(withTitles: macros.map(\ .name))
        refreshPickerSelection()
    }

    func setHotkey(_ shortcut: HotkeyShortcut) {
        hotkeyField.setShortcut(shortcut)
    }

    func setRecording(_ recording: Bool) {
        isRecording = recording
        recordButton.title = recording ? "Stop Recording" : "Record"
        statusLabel.stringValue = recording ? "Recording live input into the current macro…" : "Build and save macros independently."
    }

    func setPlaying(_ playing: Bool) {
        playButton.title = playing ? "Stop" : "Play"
    }

    private func buildLayout() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        actionStack.orientation = .vertical
        actionStack.spacing = 8
        let clipView = NSView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        clipView.addSubview(actionStack)
        NSLayoutConstraint.activate([
            actionStack.topAnchor.constraint(equalTo: clipView.topAnchor),
            actionStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            actionStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            actionStack.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
            actionStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        scrollView.documentView = clipView
        scrollView.heightAnchor.constraint(equalToConstant: 250).isActive = true

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        content.addArrangedSubview(makeHeaderSection())
        content.addArrangedSubview(makeActionsSection(scrollView: scrollView))
        content.addArrangedSubview(makeAddSection())
        content.addArrangedSubview(makePlaybackSection())
        content.addArrangedSubview(makeSection(title: "Macro Hotkey", contentView: hotkeyField))
        content.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
    }

    private func makeHeaderSection() -> NSView {
        let top = NSStackView(views: [nameField, newButton, saveButton])
        top.orientation = .horizontal
        top.spacing = 10
        let bottom = NSStackView(views: [NSTextField(labelWithString: "Saved Macros"), macroPicker])
        bottom.orientation = .horizontal
        bottom.spacing = 10
        bottom.alignment = .centerY
        let stack = NSStackView(views: [top, bottom])
        stack.orientation = .vertical
        stack.spacing = 10
        return makeSection(title: "Current Macro", contentView: stack)
    }

    private func makeActionsSection(scrollView: NSScrollView) -> NSView {
        makeSection(title: "Action List", contentView: scrollView)
    }

    private func makeAddSection() -> NSView {
        let mouseRow = NSStackView(views: [addLeftClickButton, addRightClickButton])
        mouseRow.orientation = .horizontal
        mouseRow.spacing = 10
        let comboRow = NSStackView(views: [comboField, addComboButton])
        comboRow.orientation = .horizontal
        comboRow.spacing = 10
        let pauseRow = NSStackView(views: [pauseField, addPauseButton])
        pauseRow.orientation = .horizontal
        pauseRow.spacing = 10
        pauseField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let stack = NSStackView(views: [mouseRow, comboRow, pauseRow])
        stack.orientation = .vertical
        stack.spacing = 10
        return makeSection(title: "Add Actions", contentView: stack)
    }

    private func makePlaybackSection() -> NSView {
        let loopRow = NSStackView(views: [loopField, untilStoppedButton, speedSelector])
        loopRow.orientation = .horizontal
        loopRow.spacing = 10
        loopField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        let buttons = NSStackView(views: [recordButton, playButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let stack = NSStackView(views: [loopRow, buttons])
        stack.orientation = .vertical
        stack.spacing = 10
        return makeSection(title: "Playback & Recording", contentView: stack)
    }

    private func makeSection(title: String, contentView: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        let stack = NSStackView(views: [label, contentView])
        stack.orientation = .vertical
        stack.spacing = 8
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

    private func refreshActions() {
        actionStack.arrangedSubviews.forEach {
            actionStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        if currentDocument.actions.isEmpty {
            let label = NSTextField(labelWithString: "No actions yet. Add clicks, key combos, pauses, or record one live.")
            label.textColor = .secondaryLabelColor
            actionStack.addArrangedSubview(label)
            return
        }
        for (index, action) in currentDocument.actions.enumerated() {
            let row = ActionRowView(action: action, onDelete: { [weak self] in
                self?.deleteAction(at: index)
            }, onPauseUpdated: { [weak self] newValue in
                self?.updatePause(at: index, milliseconds: newValue)
            })
            actionStack.addArrangedSubview(row)
        }
    }

    private func refreshPickerSelection() {
        if let index = savedMacros.firstIndex(where: { $0.id == currentDocument.id }) {
            macroPicker.selectItem(at: index)
        } else {
            macroPicker.selectItem(at: -1)
        }
    }

    private func appendAction(_ action: MacroAction) {
        currentDocument.actions.append(action)
        onDocumentChanged?(currentDocument)
        refreshActions()
    }

    private func deleteAction(at index: Int) {
        currentDocument.actions.remove(at: index)
        onDocumentChanged?(currentDocument)
        refreshActions()
    }

    private func updatePause(at index: Int, milliseconds: Int) {
        currentDocument.actions[index] = .pause(milliseconds: milliseconds)
        onDocumentChanged?(currentDocument)
        refreshActions()
    }

    private func currentLoopMode() -> MacroLoopMode {
        untilStoppedButton.state == .on ? .untilStopped : .count(max(loopField.integerValue, 1))
    }

    private func currentSpeed() -> Double {
        switch speedSelector.titleOfSelectedItem {
        case "0.25×": 0.25
        case "0.5×": 0.5
        case "2×": 2
        case "4×": 4
        default: 1
        }
    }

    @objc private func nameChanged() {
        currentDocument.name = nameField.stringValue.isEmpty ? "Untitled Macro" : nameField.stringValue
        onDocumentChanged?(currentDocument)
    }

    @objc private func selectionChanged() {
        guard savedMacros.indices.contains(macroPicker.indexOfSelectedItem) else { return }
        onSelectionChanged?(savedMacros[macroPicker.indexOfSelectedItem].id)
    }

    @objc private func newMacro() {
        onNewRequested?()
    }

    @objc private func saveMacro() {
        onSaveRequested?()
    }

    @objc private func addLeftClick() {
        appendAction(.mouseClick(button: .left, point: mouseLocationProvider?() ?? .zero))
    }

    @objc private func addRightClick() {
        appendAction(.mouseClick(button: .right, point: mouseLocationProvider?() ?? .zero))
    }

    @objc private func addCombo() {
        appendAction(.keyCombo(pendingCombo))
    }

    @objc private func addPause() {
        appendAction(.pause(milliseconds: max(pauseField.integerValue, 0)))
    }

    @objc private func toggleRecording() {
        onRecordingToggle?(!isRecording)
    }

    @objc private func togglePlayback() {
        onPlaybackToggle?(currentLoopMode(), currentSpeed())
    }
}
#endif
