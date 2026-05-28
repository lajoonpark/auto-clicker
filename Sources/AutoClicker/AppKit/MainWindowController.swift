#if canImport(AppKit)
import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    init(contentViewController: NSViewController) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AutoClicker"
        window.minSize = NSSize(width: 520, height: 620)
        window.contentViewController = contentViewController
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
