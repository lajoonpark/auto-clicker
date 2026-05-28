public enum AutoClickerEntry {
    @MainActor
    public static func run() {
        #if canImport(AppKit)
        AppBootstrap.run()
        #else
        print("AutoClicker is a macOS AppKit app. Build and run it on macOS.")
        #endif
    }
}
