#if canImport(AppKit)
import AppKit

@MainActor
enum AppBootstrap {
    static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
#endif
