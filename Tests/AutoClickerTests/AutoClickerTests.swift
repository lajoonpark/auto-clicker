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
