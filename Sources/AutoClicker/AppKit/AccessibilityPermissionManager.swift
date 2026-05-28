#if canImport(AppKit)
import AppKit
import ApplicationServices

@MainActor
public enum AccessibilityPermissionManager {
    public static func isTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    public static func promptIfNeeded(window: NSWindow?) {
        guard !isTrusted(prompt: true) else { return }
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "AutoClicker needs Accessibility permission to simulate clicks, hold keys, and listen for global shortcuts."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        let response = window == nil ? alert.runModal() : alert.beginSheetModal(for: window!) { response in
            if response == .alertFirstButtonReturn { openSystemSettings() }
        }
        if response == .alertFirstButtonReturn { openSystemSettings() }
    }

    public static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
