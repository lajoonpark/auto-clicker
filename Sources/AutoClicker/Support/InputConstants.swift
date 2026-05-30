import Foundation

enum InputConstants {
    static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
    static let minimumPlaybackSpeedMultiplier = 0.1
    static let defaultCombo = KeyCombo(keyCodes: [8], modifiers: [.command])
}
