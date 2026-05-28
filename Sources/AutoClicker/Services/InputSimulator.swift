import Foundation

public protocol InputSimulation: Sendable {
    func currentPointerLocation() -> ScreenPoint
    func click(_ button: MouseButton, at point: ScreenPoint)
    func holdDown(_ button: MouseButton)
    func release(_ button: MouseButton)
    func pressKey(_ keyCode: UInt16, modifiers: [ModifierKey])
    func holdKey(_ keyCode: UInt16, modifiers: [ModifierKey])
    func releaseKey(_ keyCode: UInt16, modifiers: [ModifierKey])
    func pressCombo(_ combo: KeyCombo)
    func holdCombo(_ combo: KeyCombo)
    func releaseCombo(_ combo: KeyCombo)
}

public final class InputSimulator: InputSimulation, @unchecked Sendable {
    public init() {}

    public func currentPointerLocation() -> ScreenPoint {
        #if canImport(AppKit)
        let point = InputSimulatorPlatform.currentMouseLocation()
        return ScreenPoint(x: point.x, y: point.y)
        #else
        return .zero
        #endif
    }

    public func click(_ button: MouseButton, at point: ScreenPoint) {
        #if canImport(AppKit)
        InputSimulatorPlatform.click(button, at: point)
        #endif
    }

    public func holdDown(_ button: MouseButton) {
        #if canImport(AppKit)
        InputSimulatorPlatform.holdMouse(button)
        #endif
    }

    public func release(_ button: MouseButton) {
        #if canImport(AppKit)
        InputSimulatorPlatform.releaseMouse(button)
        #endif
    }

    public func pressKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {
        holdKey(keyCode, modifiers: modifiers)
        releaseKey(keyCode, modifiers: modifiers)
    }

    public func holdKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {
        #if canImport(AppKit)
        InputSimulatorPlatform.holdKey(keyCode, modifiers: modifiers)
        #endif
    }

    public func releaseKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {
        #if canImport(AppKit)
        InputSimulatorPlatform.releaseKey(keyCode, modifiers: modifiers)
        #endif
    }

    public func pressCombo(_ combo: KeyCombo) {
        holdCombo(combo)
        releaseCombo(combo)
    }

    public func holdCombo(_ combo: KeyCombo) {
        #if canImport(AppKit)
        InputSimulatorPlatform.holdCombo(combo)
        #endif
    }

    public func releaseCombo(_ combo: KeyCombo) {
        #if canImport(AppKit)
        InputSimulatorPlatform.releaseCombo(combo)
        #endif
    }
}
