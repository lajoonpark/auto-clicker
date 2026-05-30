#if canImport(AppKit)
import AppKit

internal enum InterfaceStyling {
    static func cardBackground(blendFraction: CGFloat) -> CGColor {
        (NSColor.windowBackgroundColor.blended(withFraction: blendFraction, of: .controlBackgroundColor) ?? .controlBackgroundColor).cgColor
    }

    static func configureCell(for field: NSTextField, _ configure: (NSTextFieldCell) -> Void) {
        guard let cell = field.cell as? NSTextFieldCell else { return }
        configure(cell)
    }
}
#endif
