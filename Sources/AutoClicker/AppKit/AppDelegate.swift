#if canImport(AppKit)
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        let windowController = coordinator.makeWindowController()
        self.windowController = windowController
        windowController.showWindow(nil)
        windowController.window?.center()
        AccessibilityPermissionManager.promptIfNeeded(window: windowController.window)
        coordinator.startHotkeysIfPossible()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
