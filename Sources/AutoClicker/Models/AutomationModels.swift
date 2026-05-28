import Foundation

public enum MouseButton: String, Codable, CaseIterable, Sendable {
    case left
    case right

    public var displayName: String {
        switch self {
        case .left: "Left Click"
        case .right: "Right Click"
        }
    }
}

public enum ModifierKey: String, Codable, CaseIterable, Sendable {
    case command
    case option
    case control
    case shift

    public var symbol: String {
        switch self {
        case .command: "⌘"
        case .option: "⌥"
        case .control: "⌃"
        case .shift: "⇧"
        }
    }
}

public struct HotkeyShortcut: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: [ModifierKey]

    public init(keyCode: UInt16, modifiers: [ModifierKey]) {
        self.keyCode = keyCode
        self.modifiers = modifiers.sorted { $0.rawValue < $1.rawValue }
    }
}

public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public var keyCodes: [UInt16]
    public var modifiers: [ModifierKey]

    public init(keyCodes: [UInt16], modifiers: [ModifierKey]) {
        self.keyCodes = Array(NSOrderedSet(array: keyCodes)) as? [UInt16] ?? keyCodes
        self.modifiers = modifiers.sorted { $0.rawValue < $1.rawValue }
    }
}

public struct ScreenPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = ScreenPoint(x: 0, y: 0)
}

public enum MacroAction: Codable, Equatable, Sendable {
    case mouseClick(button: MouseButton, point: ScreenPoint)
    case keyCombo(KeyCombo)
    case pause(milliseconds: Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case button
        case point
        case combo
        case milliseconds
    }

    private enum ActionType: String, Codable {
        case mouseClick
        case keyCombo
        case pause
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ActionType.self, forKey: .type) {
        case .mouseClick:
            let button = try container.decode(MouseButton.self, forKey: .button)
            let point = try container.decode(ScreenPoint.self, forKey: .point)
            self = .mouseClick(button: button, point: point)
        case .keyCombo:
            self = .keyCombo(try container.decode(KeyCombo.self, forKey: .combo))
        case .pause:
            self = .pause(milliseconds: try container.decode(Int.self, forKey: .milliseconds))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .mouseClick(button, point):
            try container.encode(ActionType.mouseClick, forKey: .type)
            try container.encode(button, forKey: .button)
            try container.encode(point, forKey: .point)
        case let .keyCombo(combo):
            try container.encode(ActionType.keyCombo, forKey: .type)
            try container.encode(combo, forKey: .combo)
        case let .pause(milliseconds):
            try container.encode(ActionType.pause, forKey: .type)
            try container.encode(milliseconds, forKey: .milliseconds)
        }
    }
}

public struct MacroDocument: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var actions: [MacroAction]

    public init(id: UUID = UUID(), name: String, actions: [MacroAction] = []) {
        self.id = id
        self.name = name
        self.actions = actions
    }
}

public enum AutomationFeature: String, Codable, CaseIterable, Sendable {
    case autoClicker
    case keyHolder
    case macro

    public var title: String {
        switch self {
        case .autoClicker: "Auto Clicker"
        case .keyHolder: "Key Holder"
        case .macro: "Macro"
        }
    }
}

public enum KeyHolderMode: String, Codable, CaseIterable, Sendable {
    case toggle
    case whilePressed
}

public enum HoldTarget: Codable, Equatable, Sendable {
    case mouse(MouseButton)
    case keyCombo(KeyCombo)

    private enum CodingKeys: String, CodingKey {
        case type
        case button
        case combo
    }

    private enum TargetType: String, Codable {
        case mouse
        case keyCombo
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(TargetType.self, forKey: .type) {
        case .mouse:
            self = .mouse(try container.decode(MouseButton.self, forKey: .button))
        case .keyCombo:
            self = .keyCombo(try container.decode(KeyCombo.self, forKey: .combo))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .mouse(button):
            try container.encode(TargetType.mouse, forKey: .type)
            try container.encode(button, forKey: .button)
        case let .keyCombo(combo):
            try container.encode(TargetType.keyCombo, forKey: .type)
            try container.encode(combo, forKey: .combo)
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var autoClickerHotkey: HotkeyShortcut
    public var keyHolderHotkey: HotkeyShortcut
    public var macroHotkey: HotkeyShortcut

    public init(
        autoClickerHotkey: HotkeyShortcut = .init(keyCode: 42, modifiers: [.command]),
        keyHolderHotkey: HotkeyShortcut = .init(keyCode: 25, modifiers: [.command]),
        macroHotkey: HotkeyShortcut = .init(keyCode: 29, modifiers: [.command])
    ) {
        self.autoClickerHotkey = autoClickerHotkey
        self.keyHolderHotkey = keyHolderHotkey
        self.macroHotkey = macroHotkey
    }

    public func hotkey(for feature: AutomationFeature) -> HotkeyShortcut {
        switch feature {
        case .autoClicker: autoClickerHotkey
        case .keyHolder: keyHolderHotkey
        case .macro: macroHotkey
        }
    }

    public mutating func setHotkey(_ shortcut: HotkeyShortcut, for feature: AutomationFeature) {
        switch feature {
        case .autoClicker: autoClickerHotkey = shortcut
        case .keyHolder: keyHolderHotkey = shortcut
        case .macro: macroHotkey = shortcut
        }
    }
}

public enum AutoClickRepeatMode: Equatable, Sendable {
    case untilStopped
    case count(Int)
}

public struct AutoClickConfiguration: Equatable, Sendable {
    public var button: MouseButton
    public var intervalMilliseconds: Int
    public var repeatMode: AutoClickRepeatMode

    public init(button: MouseButton, intervalMilliseconds: Int, repeatMode: AutoClickRepeatMode) {
        self.button = button
        self.intervalMilliseconds = intervalMilliseconds
        self.repeatMode = repeatMode
    }
}

public enum MacroLoopMode: Equatable, Sendable {
    case untilStopped
    case count(Int)
}
