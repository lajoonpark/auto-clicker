#if canImport(AppKit)
import AppKit
import CoreGraphics

enum InputSimulatorPlatform {
    // Keep a short 30ms pause so targets reliably observe a full mouse-down/mouse-up click sequence.
    private static let clickUpDelayMilliseconds: useconds_t = 30

    static func currentMouseLocation() -> CGPoint {
        currentCGMouseLocation() ?? .zero
    }

    static func click(_ button: MouseButton) {
        performClickAtCurrentCGMouseLocation(button)
    }

    static func click(_ button: MouseButton, at point: ScreenPoint) {
        postClick(button, at: cgPoint(for: point))
    }

    static func holdMouse(_ button: MouseButton) {
        let point = currentMouseLocation()
        guard let event = CGEvent(mouseEventSource: eventSource(), mouseType: mouseDownType(for: button), mouseCursorPosition: point, mouseButton: cgButton(for: button)) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }

    static func releaseMouse(_ button: MouseButton) {
        let point = currentMouseLocation()
        guard let event = CGEvent(mouseEventSource: eventSource(), mouseType: mouseUpType(for: button), mouseCursorPosition: point, mouseButton: cgButton(for: button)) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }

    static func holdKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {
        holdModifiers(modifiers)
        guard let event = CGEvent(keyboardEventSource: eventSource(), virtualKey: CGKeyCode(keyCode), keyDown: true) else { return }
        event.flags = flags(for: modifiers)
        event.post(tap: .cghidEventTap)
    }

    static func releaseKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {
        guard let event = CGEvent(keyboardEventSource: eventSource(), virtualKey: CGKeyCode(keyCode), keyDown: false) else { return }
        event.flags = flags(for: modifiers)
        event.post(tap: .cghidEventTap)
        releaseModifiers(modifiers)
    }

    static func holdCombo(_ combo: KeyCombo) {
        holdModifiers(combo.modifiers)
        for keyCode in combo.keyCodes {
            guard let event = CGEvent(keyboardEventSource: eventSource(), virtualKey: CGKeyCode(keyCode), keyDown: true) else { continue }
            event.flags = flags(for: combo.modifiers)
            event.post(tap: .cghidEventTap)
        }
    }

    static func releaseCombo(_ combo: KeyCombo) {
        for keyCode in combo.keyCodes.reversed() {
            guard let event = CGEvent(keyboardEventSource: eventSource(), virtualKey: CGKeyCode(keyCode), keyDown: false) else { continue }
            event.flags = flags(for: combo.modifiers)
            event.post(tap: .cghidEventTap)
        }
        releaseModifiers(combo.modifiers)
    }

    static func flags(for modifiers: [ModifierKey]) -> CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { result, modifier in
            switch modifier {
            case .command: result.insert(.maskCommand)
            case .option: result.insert(.maskAlternate)
            case .control: result.insert(.maskControl)
            case .shift: result.insert(.maskShift)
            }
        }
    }

    private static func holdModifiers(_ modifiers: [ModifierKey]) {
        for modifier in modifiers {
            postModifier(modifier, keyDown: true, activeModifiers: modifiers)
        }
    }

    private static func releaseModifiers(_ modifiers: [ModifierKey]) {
        for modifier in modifiers.reversed() {
            postModifier(modifier, keyDown: false, activeModifiers: modifiers)
        }
    }

    private static func postModifier(_ modifier: ModifierKey, keyDown: Bool, activeModifiers: [ModifierKey]) {
        guard let event = CGEvent(keyboardEventSource: eventSource(), virtualKey: modifierKeyCode(for: modifier), keyDown: keyDown) else { return }
        event.flags = flags(for: activeModifiers)
        event.post(tap: .cghidEventTap)
    }

    private static func eventSource() -> CGEventSource? {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
        return source
    }

    private static func currentCGMouseLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    private static func performClickAtCurrentCGMouseLocation(_ button: MouseButton) {
        guard let location = currentCGMouseLocation() else {
            NSLog("Auto-click failed: could not read CG mouse location")
            return
        }

        let source = eventSource()
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: mouseDownType(for: button),
            mouseCursorPosition: location,
            mouseButton: cgButton(for: button)
        ),
        let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: mouseUpType(for: button),
            mouseCursorPosition: location,
            mouseButton: cgButton(for: button)
        ) else {
            NSLog("Auto-click failed: could not create mouse events")
            return
        }

        mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseDown.post(tap: .cghidEventTap)
        usleep(clickUpDelayMilliseconds * 1_000)
        mouseUp.post(tap: .cghidEventTap)
    }

    private static func postClick(_ button: MouseButton, at location: CGPoint) {
        let source = eventSource()
        guard let down = CGEvent(mouseEventSource: source, mouseType: mouseDownType(for: button), mouseCursorPosition: location, mouseButton: cgButton(for: button)),
              let up = CGEvent(mouseEventSource: source, mouseType: mouseUpType(for: button), mouseCursorPosition: location, mouseButton: cgButton(for: button)) else {
            return
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func modifierKeyCode(for modifier: ModifierKey) -> CGKeyCode {
        switch modifier {
        case .command: 55
        case .shift: 56
        case .option: 58
        case .control: 59
        }
    }

    private static func cgPoint(for point: ScreenPoint) -> CGPoint {
        CGPoint(x: point.x, y: point.y)
    }

    private static func cgButton(for button: MouseButton) -> CGMouseButton {
        switch button {
        case .left: .left
        case .right: .right
        }
    }

    private static func mouseDownType(for button: MouseButton) -> CGEventType {
        switch button {
        case .left: .leftMouseDown
        case .right: .rightMouseDown
        }
    }

    private static func mouseUpType(for button: MouseButton) -> CGEventType {
        switch button {
        case .left: .leftMouseUp
        case .right: .rightMouseUp
        }
    }
}
#endif
