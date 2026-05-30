import Dispatch
import Foundation

public final class AutoClickerController: @unchecked Sendable {
    private let simulator: InputSimulation
    private let queue = DispatchQueue(label: "autoclicker.timer")
    private var timer: DispatchSourceTimer?
    private let lock = NSLock()
    public var onStateChange: ((Bool) -> Void)?

    public init(simulator: InputSimulation) {
        self.simulator = simulator
    }

    public var isRunning: Bool {
        lock.withLock { timer != nil }
    }

    public func start(configuration: AutoClickConfiguration) {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        var remaining = repeatCount(from: configuration.repeatMode)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let location = self.simulator.currentPointerLocation()
            self.simulator.click(configuration.button, at: location)
            if let value = remaining {
                remaining = value - 1
                if remaining == 0 {
                    self.stop()
                    return
                }
            }
            let nextInterval = self.intervalMilliseconds(from: configuration.intervalMode)
            timer.schedule(deadline: .now() + .milliseconds(nextInterval))
        }
        lock.withLock { self.timer = timer }
        timer.schedule(deadline: .now())
        timer.resume()
        DispatchQueue.main.async { self.onStateChange?(true) }
    }

    public func stop() {
        let timer = lock.withLock { () -> DispatchSourceTimer? in
            defer { self.timer = nil }
            return self.timer
        }
        timer?.cancel()
        DispatchQueue.main.async { self.onStateChange?(false) }
    }

    public func toggle(configuration: AutoClickConfiguration) {
        isRunning ? stop() : start(configuration: configuration)
    }

    private func repeatCount(from mode: AutoClickRepeatMode) -> Int? {
        switch mode {
        case .untilStopped: nil
        case let .count(value): max(value, 1)
        }
    }

    private func intervalMilliseconds(from mode: AutoClickIntervalMode) -> Int {
        switch mode {
        case let .fixed(value):
            return max(value, 10)
        case let .random(minMilliseconds, maxMilliseconds):
            let lowerBound = max(minMilliseconds, 10)
            let upperBound = max(maxMilliseconds, lowerBound)
            return Int.random(in: lowerBound...upperBound)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}
