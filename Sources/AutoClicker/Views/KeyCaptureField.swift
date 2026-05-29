#if canImport(AppKit)
import AppKit

public final class KeyCaptureField: NSTextField {
    private static let returnKeyCode: UInt16 = 36

    public enum CaptureStyle {
        case hotkey
        case combo(maximumKeys: Int)
    }

    public var onHotkeyCaptured: ((HotkeyShortcut) -> Void)?
    public var onComboCaptured: ((KeyCombo) -> Void)?
    private let style: CaptureStyle
    private var capturedKeys: [UInt16] = []
    private var capturedModifiers: [ModifierKey] = []
    private var lastAppliedCombo: KeyCombo?
    private var placeholderText: String

    public init(style: CaptureStyle, placeholder: String) {
        self.style = style
        self.placeholderText = placeholder
        super.init(frame: .zero)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.style = .hotkey
        self.placeholderText = "Click and press keys"
        super.init(coder: coder)
        commonInit()
    }

    public override var acceptsFirstResponder: Bool { true }

    public func setShortcut(_ shortcut: HotkeyShortcut) {
        stringValue = KeyFormatter.label(for: shortcut)
    }

    public func setCombo(_ combo: KeyCombo) {
        stringValue = KeyFormatter.label(for: combo)
    }

    public override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            capturedKeys = []
            capturedModifiers = []
            lastAppliedCombo = nil
            stringValue = "Recording…"
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
        return accepted
    }

    public override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned, stringValue == "Recording…" {
            stringValue = placeholderText
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
        return resigned
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            stringValue = placeholderText
            return
        }

        capturedModifiers = modifiers(from: event.modifierFlags)
        guard !isModifier(event.keyCode) else {
            updatePreview()
            return
        }

        switch style {
        case .hotkey:
            let shortcut = HotkeyShortcut(keyCode: event.keyCode, modifiers: capturedModifiers)
            stringValue = KeyFormatter.label(for: shortcut)
            onHotkeyCaptured?(shortcut)
            window?.makeFirstResponder(nil)
        case let .combo(maximumKeys):
            if event.keyCode == Self.returnKeyCode {
                if !capturedKeys.isEmpty {
                    applyCapturedCombo()
                }
                window?.makeFirstResponder(nil)
                return
            }
            if !capturedKeys.contains(event.keyCode), capturedKeys.count < maximumKeys {
                capturedKeys.append(event.keyCode)
            }
            if !capturedKeys.isEmpty {
                applyCapturedCombo()
            }
            updatePreview()
        }
    }

    public override func flagsChanged(with event: NSEvent) {
        capturedModifiers = modifiers(from: event.modifierFlags)
        updatePreview()
    }

    private func updatePreview() {
        switch style {
        case .hotkey:
            stringValue = capturedModifiers.isEmpty ? "Recording…" : capturedModifiers.map(\.symbol).joined()
        case .combo:
            let combo = KeyCombo(keyCodes: capturedKeys, modifiers: capturedModifiers)
            let label = KeyFormatter.label(for: combo)
            stringValue = label.isEmpty ? "Recording…" : label
        }
    }

    private func applyCapturedCombo() {
        let combo = KeyCombo(keyCodes: capturedKeys, modifiers: capturedModifiers)
        stringValue = KeyFormatter.label(for: combo)
        if combo != lastAppliedCombo {
            onComboCaptured?(combo)
            lastAppliedCombo = combo
        }
    }

    private func commonInit() {
        isEditable = false
        isBordered = false
        isBezeled = false
        backgroundColor = .controlBackgroundColor
        alignment = .center
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        drawsBackground = true
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        stringValue = placeholderText
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func modifiers(from flags: NSEvent.ModifierFlags) -> [ModifierKey] {
        var modifiers: [ModifierKey] = []
        if flags.contains(.command) { modifiers.append(.command) }
        if flags.contains(.option) { modifiers.append(.option) }
        if flags.contains(.control) { modifiers.append(.control) }
        if flags.contains(.shift) { modifiers.append(.shift) }
        return modifiers.sorted { $0.rawValue < $1.rawValue }
    }

    private func isModifier(_ keyCode: UInt16) -> Bool {
        InputConstants.modifierKeyCodes.contains(keyCode)
    }
}
#endif
