#if canImport(AppKit)
import AppKit

public final class ModernButton: NSButton {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public var isProminent: Bool = false {
        didSet { needsDisplay = true }
    }

    public override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let background = isProminent ? NSColor.controlAccentColor : NSColor.controlBackgroundColor
        let stroke = isProminent
            ? NSColor.controlAccentColor.shadow(withLevel: 0.25) ?? NSColor.separatorColor
            : NSColor.separatorColor
        background.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        path.fill()
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
        super.draw(dirtyRect)
    }

    private func configure() {
        bezelStyle = .regularSquare
        isBordered = false
        wantsLayer = true
        setButtonType(.momentaryPushIn)
        font = .systemFont(ofSize: 13, weight: .semibold)
        contentTintColor = .labelColor
        imagePosition = .imageLeading
    }
}
#endif
