import Foundation
import Testing
@testable import AutoClicker

@Test func macroStoreRoundTripsDocuments() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let store = MacroStore(paths: ApplicationSupportPaths(baseURL: root))
    let document = MacroDocument(name: "Sample", actions: [
        .mouseClick(button: .left, point: .init(x: 40, y: 50)),
        .pause(milliseconds: 300),
        .keyCombo(.init(keyCodes: [8], modifiers: [.command]))
    ])

    try store.save(document)
    let loaded = try store.loadAll()

    #expect(loaded == [document])
}

@Test func settingsStoreFallsBackToDefaults() {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let store = SettingsStore(paths: ApplicationSupportPaths(baseURL: root))

    #expect(store.load() == AppSettings())
}

@Test func macroRunnerReplaysActionsInOrder() async throws {
    let simulator = MockSimulator()
    let runner = MacroRunner(simulator: simulator)
    let document = MacroDocument(name: "Playback", actions: [
        .mouseClick(button: .right, point: .init(x: 10, y: 20)),
        .pause(milliseconds: 5),
        .keyCombo(.init(keyCodes: [8], modifiers: [.command]))
    ])

    runner.start(document: document, loopMode: .count(1), speedMultiplier: 1)
    try await Task.sleep(for: .milliseconds(80))

    #expect(simulator.events == [
        "click:right:10.0:20.0",
        "combo:command:C"
    ])
}

@Test func autoClickerControllerSupportsRandomIntervalRange() async throws {
    let simulator = CountingSimulator()
    let controller = AutoClickerController(simulator: simulator)
    controller.start(configuration: .init(
        button: .left,
        intervalMode: .random(minMilliseconds: 10, maxMilliseconds: 30),
        repeatMode: .count(3)
    ))

    try await Task.sleep(for: .milliseconds(140))

    #expect(simulator.clickCount == 3)
    #expect(controller.isRunning == false)
}

#if canImport(AppKit)
import AppKit

@MainActor
@Test func macroViewControllerCreatesScrollableActionList() {
    let controller = MacroViewController()

    _ = controller.view

    let scrollViews = controller.view.allDescendantViews().compactMap { $0 as? NSScrollView }
    #expect(scrollViews.count == 1)
    #expect(scrollViews[0].documentView != nil)
    #expect(scrollViews[0].documentView?.isFlipped == true)
}

private extension NSView {
    func allDescendantViews() -> [NSView] {
        subviews + subviews.flatMap { $0.allDescendantViews() }
    }
}
#endif

private final class MockSimulator: InputSimulation, @unchecked Sendable {
    var events: [String] = []

    func currentPointerLocation() -> ScreenPoint { .zero }
    func click(_ button: MouseButton, at point: ScreenPoint) { events.append("click:\(button.rawValue):\(point.x):\(point.y)") }
    func holdDown(_ button: MouseButton) {}
    func release(_ button: MouseButton) {}
    func pressKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {}
    func holdKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {}
    func releaseKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {}
    func pressCombo(_ combo: KeyCombo) { events.append("combo:\(combo.modifiers.map(\.rawValue).joined(separator: "+")):\(combo.keyCodes.map(KeyFormatter.label(for:)).joined(separator: "+"))") }
    func holdCombo(_ combo: KeyCombo) {}
    func releaseCombo(_ combo: KeyCombo) {}
}

private final class CountingSimulator: InputSimulation, @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()

    var clickCount: Int {
        lock.withLock { count }
    }

    func currentPointerLocation() -> ScreenPoint {
        .zero
    }

    func click(_ button: MouseButton, at point: ScreenPoint) {
        lock.withLock { count += 1 }
    }

    func holdDown(_ button: MouseButton) {}
    func release(_ button: MouseButton) {}
    func pressKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {}
    func holdKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {}
    func releaseKey(_ keyCode: UInt16, modifiers: [ModifierKey]) {}
    func pressCombo(_ combo: KeyCombo) {}
    func holdCombo(_ combo: KeyCombo) {}
    func releaseCombo(_ combo: KeyCombo) {}
}

private extension NSLock {
    func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}
