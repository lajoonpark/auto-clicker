import Foundation

public final class KeyHolderController: @unchecked Sendable {
    private let simulator: InputSimulation
    public var onStateChange: ((Bool) -> Void)?
    private(set) public var isHolding = false
    private var activeTarget: HoldTarget?

    public init(simulator: InputSimulation) {
        self.simulator = simulator
    }

    public func start(target: HoldTarget) {
        stop()
        switch target {
        case let .mouse(button):
            simulator.holdDown(button)
        case let .keyCombo(combo):
            simulator.holdCombo(combo)
        }
        activeTarget = target
        isHolding = true
        onStateChange?(true)
    }

    public func stop() {
        guard let activeTarget else { return }
        switch activeTarget {
        case let .mouse(button):
            simulator.release(button)
        case let .keyCombo(combo):
            simulator.releaseCombo(combo)
        }
        self.activeTarget = nil
        isHolding = false
        onStateChange?(false)
    }

    public func toggle(target: HoldTarget) {
        isHolding ? stop() : start(target: target)
    }
}
