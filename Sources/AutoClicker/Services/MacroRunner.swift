import Foundation

public final class MacroRunner: @unchecked Sendable {
    private let simulator: InputSimulation
    private var task: Task<Void, Never>?
    @MainActor public var onStateChange: ((Bool) -> Void)?

    public init(simulator: InputSimulation) {
        self.simulator = simulator
    }

    public var isRunning: Bool { task != nil }

    public func start(document: MacroDocument, loopMode: MacroLoopMode, speedMultiplier: Double) {
        stop()
        let multiplier = max(speedMultiplier, 0.1)
        task = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.onStateChange?(true) }
            defer {
                Task { @MainActor in self.onStateChange?(false) }
                self.task = nil
            }
            let iterations = Self.iterationCount(for: loopMode)
            var completed = 0
            while !Task.isCancelled {
                for action in document.actions {
                    if Task.isCancelled { break }
                    try? await Self.run(action: action, multiplier: multiplier, simulator: self.simulator)
                }
                if let iterations {
                    completed += 1
                    if completed >= iterations { break }
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        Task { @MainActor in onStateChange?(false) }
    }

    public func toggle(document: MacroDocument, loopMode: MacroLoopMode, speedMultiplier: Double) {
        isRunning ? stop() : start(document: document, loopMode: loopMode, speedMultiplier: speedMultiplier)
    }

    private static func iterationCount(for mode: MacroLoopMode) -> Int? {
        switch mode {
        case .untilStopped: nil
        case let .count(value): max(value, 1)
        }
    }

    private static func run(action: MacroAction, multiplier: Double, simulator: InputSimulation) async throws {
        switch action {
        case let .mouseClick(button, point):
            simulator.click(button, at: point)
        case let .keyCombo(combo):
            simulator.pressCombo(combo)
        case let .pause(milliseconds):
            let adjusted = max(Double(milliseconds) / multiplier, 1)
            try await Task.sleep(for: .milliseconds(Int(adjusted)))
        }
    }
}
