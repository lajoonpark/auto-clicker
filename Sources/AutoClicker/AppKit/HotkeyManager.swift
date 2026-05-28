#if canImport(AppKit)
import AppKit
import CoreGraphics

public enum HotkeyEventPhase {
    case keyDown
    case keyUp
}

public final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcuts: [AutomationFeature: HotkeyShortcut] = [:]
    private var handler: ((AutomationFeature, HotkeyEventPhase) -> Void)?

    public init() {}

    deinit {
        stop()
    }

    public func start(shortcuts: [AutomationFeature: HotkeyShortcut], handler: @escaping (AutomationFeature, HotkeyEventPhase) -> Void) {
        stop()
        self.shortcuts = shortcuts
        self.handler = handler

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            return manager.handle(event: event, type: type)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    public func update(shortcut: HotkeyShortcut, for feature: AutomationFeature) {
        shortcuts[feature] = shortcut
    }

    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout, let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let shortcut = HotkeyShortcut(keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)), modifiers: modifiers(from: event.flags))
        guard let feature = shortcuts.first(where: { $0.value == shortcut })?.key else {
            return Unmanaged.passUnretained(event)
        }
        handler?(feature, type == .keyDown ? .keyDown : .keyUp)
        return nil
    }

    private func modifiers(from flags: CGEventFlags) -> [ModifierKey] {
        var modifiers: [ModifierKey] = []
        if flags.contains(.maskCommand) { modifiers.append(.command) }
        if flags.contains(.maskAlternate) { modifiers.append(.option) }
        if flags.contains(.maskControl) { modifiers.append(.control) }
        if flags.contains(.maskShift) { modifiers.append(.shift) }
        return modifiers.sorted { $0.rawValue < $1.rawValue }
    }
}
#endif
