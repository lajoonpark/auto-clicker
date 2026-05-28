#if canImport(AppKit)
import AppKit
import CoreGraphics

@MainActor
public final class InputRecorder {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((MacroAction) -> Void)?
    private var lastTimestamp: UInt64?
    public private(set) var isRecording = false

    public init() {}

    deinit {
        stop()
    }

    public func start(handler: @escaping (MacroAction) -> Void) {
        stop()
        self.handler = handler
        lastTimestamp = nil

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<InputRecorder>.fromOpaque(userInfo).takeUnretainedValue()
            return recorder.handle(event: event, type: type)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
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
        isRecording = true
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
        handler = nil
        isRecording = false
    }

    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout, let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return Unmanaged.passUnretained(event)
        }
        appendPauseIfNeeded(for: event.timestamp)
        switch type {
        case .leftMouseDown:
            handler?(.mouseClick(button: .left, point: .init(x: event.location.x, y: event.location.y)))
        case .rightMouseDown:
            handler?(.mouseClick(button: .right, point: .init(x: event.location.x, y: event.location.y)))
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let modifiers = modifiers(from: event.flags)
            if isModifierOnly(keyCode) { return Unmanaged.passUnretained(event) }
            handler?(.keyCombo(.init(keyCodes: [keyCode], modifiers: modifiers)))
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func appendPauseIfNeeded(for timestamp: UInt64) {
        defer { lastTimestamp = timestamp }
        guard let lastTimestamp else { return }
        let difference = Int((timestamp - lastTimestamp) / 1_000_000)
        if difference > 0 {
            handler?(.pause(milliseconds: difference))
        }
    }

    private func modifiers(from flags: CGEventFlags) -> [ModifierKey] {
        var modifiers: [ModifierKey] = []
        if flags.contains(.maskCommand) { modifiers.append(.command) }
        if flags.contains(.maskAlternate) { modifiers.append(.option) }
        if flags.contains(.maskControl) { modifiers.append(.control) }
        if flags.contains(.maskShift) { modifiers.append(.shift) }
        return modifiers.sorted { $0.rawValue < $1.rawValue }
    }

    private func isModifierOnly(_ keyCode: UInt16) -> Bool {
        InputConstants.modifierKeyCodes.contains(keyCode)
    }
}
#endif
