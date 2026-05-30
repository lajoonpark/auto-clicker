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
        let scheduleNext: (Int) -> Void = { delay in
            timer.schedule(deadline: .now() + .milliseconds(delay), repeating: .never)
        }
        scheduleNext(0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            switch configuration.target {
            case let .mouse(button):
                self.simulator.click(button)
            case let .keyCombo(combo):
                self.simulator.pressCombo(combo)
            }
            if let value = remaining {
                remaining = value - 1
                if remaining == 0 {
                    self.stop()
                    return
                }
            }
            scheduleNext(Self.nextIntervalMilliseconds(for: configuration.interval))
        }
        lock.withLock { self.timer = timer }
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

    private static func nextIntervalMilliseconds(for interval: AutoClickInterval) -> Int {
        switch interval {
        case let .fixed(milliseconds):
            return max(milliseconds, 10)
        case let .randomRange(minMilliseconds, maxMilliseconds):
            let minimum = max(minMilliseconds, 10)
            let maximum = max(maxMilliseconds, 10)
            let lower = min(minimum, maximum)
            let upper = max(minimum, maximum)
            return Int.random(in: lower ... upper)
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
