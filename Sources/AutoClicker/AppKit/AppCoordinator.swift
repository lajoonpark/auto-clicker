#if canImport(AppKit)
import AppKit

@MainActor
final class AppCoordinator {
    private let simulator = InputSimulator()
    private let autoClickerController: AutoClickerController
    private let keyHolderController: KeyHolderController
    private let macroRunner: MacroRunner
    private let macroStore = MacroStore()
    private let settingsStore = SettingsStore()
    private let hotkeyManager = HotkeyManager()
    private let inputRecorder = InputRecorder()

    private var settings: AppSettings
    private var macros: [MacroDocument]
    private var currentMacro: MacroDocument

    private let autoClickerViewController = AutoClickerViewController()
    private let keyHolderViewController = KeyHolderViewController()
    private let macroViewController = MacroViewController()

    init() {
        autoClickerController = AutoClickerController(simulator: simulator)
        keyHolderController = KeyHolderController(simulator: simulator)
        macroRunner = MacroRunner(simulator: simulator)
        settings = settingsStore.load()
        macros = (try? macroStore.loadAll()) ?? []
        currentMacro = macros.first ?? MacroDocument(name: "Untitled Macro")
        wireControllers()
    }

    func makeWindowController() -> MainWindowController {
        autoClickerViewController.setHotkey(settings.autoClickerHotkey)
        autoClickerViewController.setRunning(false)
        keyHolderViewController.setHotkey(settings.keyHolderHotkey)
        keyHolderViewController.setHolding(false)
        macroViewController.setHotkey(settings.macroHotkey)
        macroViewController.setPlaying(false)
        macroViewController.setRecording(false)
        macroViewController.mouseLocationProvider = { [weak self] in self?.simulator.currentPointerLocation() ?? .zero }
        macroViewController.setMacros(macros)
        macroViewController.setDocument(currentMacro)
        let main = MainViewController(
            childControllers: [autoClickerViewController, keyHolderViewController, macroViewController],
            titles: AutomationFeature.allCases.map(\.title)
        )
        return MainWindowController(contentViewController: main)
    }

    func startHotkeysIfPossible() {
        guard AccessibilityPermissionManager.isTrusted() else {
            stopHotkeys()
            return
        }
        hotkeyManager.start(shortcuts: [
            .autoClicker: settings.autoClickerHotkey,
            .keyHolder: settings.keyHolderHotkey,
            .macro: settings.macroHotkey,
        ]) { [weak self] feature, phase in
            self?.handleHotkey(feature: feature, phase: phase)
        }
    }

    private func wireControllers() {
        autoClickerViewController.onToggleRequested = { [weak self] config in
            guard self?.checkAndPromptForAccessibilityPermission() == true else { return }
            self?.autoClickerController.toggle(configuration: config)
        }
        autoClickerViewController.onHotkeyChanged = { [weak self] shortcut in
            self?.updateHotkey(shortcut, for: .autoClicker)
        }
        autoClickerController.onStateChange = { [weak self] isRunning in
            self?.autoClickerViewController.setRunning(isRunning)
        }

        keyHolderViewController.onToggleRequested = { [weak self] target in
            guard self?.checkAndPromptForAccessibilityPermission() == true else { return }
            self?.keyHolderController.toggle(target: target)
        }
        keyHolderViewController.onStartRequested = { [weak self] target in
            guard self?.checkAndPromptForAccessibilityPermission() == true else { return }
            self?.keyHolderController.start(target: target)
        }
        keyHolderViewController.onStopRequested = { [weak self] in
            self?.keyHolderController.stop()
        }
        keyHolderViewController.onHotkeyChanged = { [weak self] shortcut in
            self?.updateHotkey(shortcut, for: .keyHolder)
        }
        keyHolderController.onStateChange = { [weak self] isHolding in
            self?.keyHolderViewController.setHolding(isHolding)
        }

        macroViewController.onDocumentChanged = { [weak self] document in
            self?.currentMacro = document
        }
        macroViewController.onSaveRequested = { [weak self] in
            self?.saveCurrentMacro()
        }
        macroViewController.onNewRequested = { [weak self] in
            self?.newMacro()
        }
        macroViewController.onDeleteRequested = { [weak self] in
            self?.deleteCurrentMacro()
        }
        macroViewController.onSelectionChanged = { [weak self] id in
            self?.selectMacro(id: id)
        }
        macroViewController.onCaptureRequested = { [weak self] request in
            self?.startSingleMacroCapture(request: request)
        }
        macroViewController.onCaptureCancelRequested = { [weak self] in
            self?.inputRecorder.cancelSingleCapture()
        }
        macroViewController.onPlaybackToggle = { [weak self] loopMode, speed in
            guard self?.checkAndPromptForAccessibilityPermission() == true else { return }
            self?.macroRunner.toggle(document: self?.currentMacro ?? MacroDocument(name: "Untitled Macro"), loopMode: loopMode, speedMultiplier: speed)
        }
        macroViewController.onRecordingToggle = { [weak self] shouldRecord in
            self?.setRecording(shouldRecord)
        }
        macroViewController.onHotkeyChanged = { [weak self] shortcut in
            self?.updateHotkey(shortcut, for: .macro)
        }
        macroRunner.onStateChange = { [weak self] isRunning in
            self?.macroViewController.setPlaying(isRunning)
        }
    }

    private func updateHotkey(_ shortcut: HotkeyShortcut, for feature: AutomationFeature) {
        settings.setHotkey(shortcut, for: feature)
        try? settingsStore.save(settings)
        switch feature {
        case .autoClicker: autoClickerViewController.setHotkey(shortcut)
        case .keyHolder: keyHolderViewController.setHotkey(shortcut)
        case .macro: macroViewController.setHotkey(shortcut)
        }
        startHotkeysIfPossible()
    }

    private func handleHotkey(feature: AutomationFeature, phase: HotkeyEventPhase) {
        switch feature {
        case .autoClicker:
            guard phase == .keyDown else { return }
            autoClickerController.toggle(configuration: autoClickerViewController.currentConfiguration())
        case .keyHolder:
            let target = keyHolderViewController.currentTarget()
            switch keyHolderViewController.holdMode {
            case .toggle:
                guard phase == .keyDown else { return }
                keyHolderController.toggle(target: target)
            case .whilePressed:
                if phase == .keyDown {
                    keyHolderController.start(target: target)
                } else {
                    keyHolderController.stop()
                }
            }
        case .macro:
            guard phase == .keyDown else { return }
            macroRunner.toggle(document: currentMacro, loopMode: macroViewController.playbackLoopMode, speedMultiplier: macroViewController.playbackSpeedMultiplier)
        }
    }

    private func newMacro() {
        currentMacro = MacroDocument(name: "Untitled Macro")
        macroViewController.setDocument(currentMacro)
    }

    private func saveCurrentMacro() {
        let trimmed = currentMacro.name.trimmingCharacters(in: .whitespacesAndNewlines)
        currentMacro.name = trimmed.isEmpty ? "Untitled Macro" : trimmed
        try? macroStore.save(currentMacro)
        macros = (try? macroStore.loadAll()) ?? macros
        if let updated = macros.first(where: { $0.id == currentMacro.id }) {
            currentMacro = updated
        }
        macroViewController.setMacros(macros)
        macroViewController.setDocument(currentMacro)
    }

    private func selectMacro(id: UUID) {
        guard let macro = macros.first(where: { $0.id == id }) else { return }
        currentMacro = macro
        macroViewController.setDocument(macro)
    }

    private func setRecording(_ shouldRecord: Bool) {
        if shouldRecord {
            guard checkAndPromptForAccessibilityPermission() else {
                macroViewController.setRecording(false)
                return
            }

            private func deleteCurrentMacro() {
                guard let existing = macros.first(where: { $0.id == currentMacro.id }) else { return }
                try? macroStore.delete(existing)
                macros = (try? macroStore.loadAll()) ?? []
                if let replacement = macros.first(where: { $0.id == currentMacro.id }) ?? macros.first {
                    currentMacro = replacement
                } else {
                    currentMacro = MacroDocument(name: "Untitled Macro")
                }
                macroViewController.setMacros(macros)
                macroViewController.setDocument(currentMacro)
            }

            private func startSingleMacroCapture(request: MacroCaptureRequest) {
                guard checkAndPromptForAccessibilityPermission() else {
                    macroViewController.captureDidCancel(reason: "Accessibility permission is required to capture input.")
                    return
                }

                let target: InputRecorder.SingleCaptureTarget
                switch request {
                case .leftClick:
                    target = .leftClick
                case .rightClick:
                    target = .rightClick
                case .keyCombo:
                    target = .keyCombo
                }

                inputRecorder.startSingleCapture(target: target, onCaptured: { [weak self] action in
                    guard let self else { return }
                    self.macroViewController.captureDidSucceed(action)
                }, onCancelled: { [weak self] reason in
                    let message: String
                    switch reason {
                    case .cancelled:
                        message = "Capture cancelled."
                    case .timedOut:
                        message = "Capture timed out."
                    }
                    self?.macroViewController.captureDidCancel(reason: message)
                })
            }
            inputRecorder.start { [weak self] action in
                guard let self else { return }
                self.currentMacro.actions.append(action)
                self.macroViewController.setDocument(self.currentMacro)
            }
        } else {
            inputRecorder.stop()
        }
        macroViewController.setRecording(shouldRecord)
    }

    private func checkAndPromptForAccessibilityPermission() -> Bool {
        guard AccessibilityPermissionManager.isTrusted() else {
            stopHotkeys()
            AccessibilityPermissionManager.promptIfNeeded(window: autoClickerViewController.view.window)
            return false
        }
        return true
    }

    private func stopHotkeys() {
        hotkeyManager.stop()
    }
}
#endif
