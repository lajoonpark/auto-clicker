#if canImport(AppKit)
import AppKit
import CoreGraphics

public final class InputRecorder {
    public enum SingleCaptureTarget {
        case leftClick
        case rightClick
        case keyCombo
    }

    public enum SingleCaptureCancellationReason {
        case cancelled
        case timedOut
    }

    private enum Mode {
        case recording
        case single(SingleCaptureTarget)
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localKeyMonitor: Any?
    private var handler: ((MacroAction) -> Void)?
    private var singleCaptureHandler: ((MacroAction) -> Void)?
    private var singleCaptureCancelled: ((SingleCaptureCancellationReason) -> Void)?
    private var singleCaptureToken: UUID?
    private var mode: Mode = .recording
    private var lastTimestamp: UInt64?
    private var latestModifierFlags: CGEventFlags = []
    private var timeoutWorkItem: DispatchWorkItem?
    public private(set) var isRecording = false

    public init() {}

    deinit {
        stop()
    }

    public func start(handler: @escaping (MacroAction) -> Void) {
        stop()
        mode = .recording
        self.handler = handler
        singleCaptureHandler = nil
        singleCaptureCancelled = nil
        lastTimestamp = nil

        let eventMask = (UInt64(1) << CGEventType.keyDown.rawValue)
            | (UInt64(1) << CGEventType.flagsChanged.rawValue)
            | (UInt64(1) << CGEventType.leftMouseDown.rawValue)
            | (UInt64(1) << CGEventType.rightMouseDown.rawValue)
        installTap(eventMask: eventMask)
        isRecording = true
    }

    public func startSingleCapture(
        target: SingleCaptureTarget,
        timeout: TimeInterval = 8,
        onCaptured: @escaping (MacroAction) -> Void,
        onCancelled: @escaping (SingleCaptureCancellationReason) -> Void
    ) {
        stop()
        mode = .single(target)
        let token = UUID()
        singleCaptureToken = token
        singleCaptureHandler = onCaptured
        singleCaptureCancelled = onCancelled
        handler = nil
        lastTimestamp = nil
        let eventMask: UInt64
        switch target {
        case .leftClick:
            eventMask = 1 << CGEventType.leftMouseDown.rawValue
        case .rightClick:
            eventMask = 1 << CGEventType.rightMouseDown.rawValue
        case .keyCombo:
            eventMask = (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
        }
        installTap(eventMask: eventMask)
        if target == .keyCombo {
            installLocalKeyMonitor()
        }
        isRecording = eventTap != nil || localKeyMonitor != nil
        guard isRecording else {
            singleCaptureCancelled?(.cancelled)
            singleCaptureHandler = nil
            singleCaptureCancelled = nil
            return
        }
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard case .single = self.mode, self.singleCaptureToken == token else { return }
            self.cancelSingleCapture(reason: .timedOut)
        }
        self.timeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
    }

    public func cancelSingleCapture(reason: SingleCaptureCancellationReason = .cancelled) {
        guard case .single = mode else { return }
        let cancellation = singleCaptureCancelled
        stop()
        cancellation?(reason)
    }

    public func stop() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        eventTap = nil
        runLoopSource = nil
        localKeyMonitor = nil
        handler = nil
        singleCaptureHandler = nil
        singleCaptureCancelled = nil
        singleCaptureToken = nil
        mode = .recording
        latestModifierFlags = []
        isRecording = false
    }

    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout, let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return Unmanaged.passUnretained(event)
        }
        switch mode {
        case .recording:
            appendPauseIfNeeded(for: event.timestamp)
            switch type {
            case .flagsChanged:
                latestModifierFlags = event.flags
            case .leftMouseDown:
                handler?(.mouseClick(button: .left, point: .init(x: event.location.x, y: event.location.y)))
            case .rightMouseDown:
                handler?(.mouseClick(button: .right, point: .init(x: event.location.x, y: event.location.y)))
            case .keyDown:
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let modifiers = modifiers(from: latestModifierFlags.union(event.flags))
                if isModifierOnly(keyCode) { return Unmanaged.passUnretained(event) }
                handler?(.keyCombo(.init(keyCodes: [keyCode], modifiers: modifiers)))
            default:
                break
            }
        case let .single(target):
            guard let action = singleAction(for: target, event: event, type: type) else {
                return Unmanaged.passUnretained(event)
            }
            let capture = singleCaptureHandler
            stop()
            capture?(action)
        }
        return Unmanaged.passUnretained(event)
    }

    private func installTap(eventMask: UInt64) {
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
    }

    private func singleAction(for target: SingleCaptureTarget, event: CGEvent, type: CGEventType) -> MacroAction? {
        switch target {
        case .leftClick:
            guard type == .leftMouseDown else { return nil }
            return .mouseClick(button: .left, point: .init(x: event.location.x, y: event.location.y))
        case .rightClick:
            guard type == .rightMouseDown else { return nil }
            return .mouseClick(button: .right, point: .init(x: event.location.x, y: event.location.y))
        case .keyCombo:
            if type == .flagsChanged {
                latestModifierFlags = event.flags
                return nil
            }
            guard type == .keyDown else { return nil }
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if isModifierOnly(keyCode) { return nil }
            let modifiers = modifiers(from: latestModifierFlags.union(event.flags))
            return .keyCombo(.init(keyCodes: [keyCode], modifiers: modifiers))
        }
    }

    private func installLocalKeyMonitor() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return event }
            guard case .single(.keyCombo) = self.mode else { return event }
            switch event.type {
            case .flagsChanged:
                self.latestModifierFlags = self.cgFlags(from: event.modifierFlags)
                return event
            case .keyDown:
                let keyCode = event.keyCode
                guard !self.isModifierOnly(keyCode) else { return event }
                let modifiers = self.modifiers(from: self.latestModifierFlags.union(self.cgFlags(from: event.modifierFlags)))
                let capture = self.singleCaptureHandler
                self.stop()
                capture?(.keyCombo(.init(keyCodes: [keyCode], modifiers: modifiers)))
                return nil
            default:
                return event
            }
        }
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

    private func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var cgFlags: CGEventFlags = []
        if flags.contains(.command) { cgFlags.insert(.maskCommand) }
        if flags.contains(.option) { cgFlags.insert(.maskAlternate) }
        if flags.contains(.control) { cgFlags.insert(.maskControl) }
        if flags.contains(.shift) { cgFlags.insert(.maskShift) }
        if flags.contains(.capsLock) { cgFlags.insert(.maskAlphaShift) }
        return cgFlags
    }

    private func isModifierOnly(_ keyCode: UInt16) -> Bool {
        InputConstants.modifierKeyCodes.contains(keyCode)
    }
}
#endif
