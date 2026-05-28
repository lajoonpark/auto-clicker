#if canImport(AppKit)
import AppKit

public final class TabBarView: NSView {
    public var onSelectionChanged: ((Int) -> Void)?
    private var buttons: [NSButton] = []
    private let stackView = NSStackView()
    public private(set) var selectedIndex = 0

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public func setTabs(_ titles: [String]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = titles.enumerated().map { index, title in
            let button = NSButton(title: title, target: self, action: #selector(selectTab(_:)))
            button.tag = index
            button.isBordered = false
            button.font = .systemFont(ofSize: 13, weight: .semibold)
            button.contentTintColor = .labelColor
            button.setButtonType(.toggle)
            stackView.addArrangedSubview(button)
            return button
        }
        select(index: 0)
    }

    public func select(index: Int) {
        selectedIndex = index
        for button in buttons {
            let active = button.tag == index
            button.state = active ? .on : .off
            button.wantsLayer = true
            button.layer?.cornerRadius = 11
            button.layer?.backgroundColor = (active ? NSColor.controlAccentColor : NSColor.clear).cgColor
            button.contentTintColor = active ? .white : .labelColor
        }
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor.windowBackgroundColor.blended(withFraction: 0.07, of: .labelColor)?.cgColor
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func selectTab(_ sender: NSButton) {
        select(index: sender.tag)
        onSelectionChanged?(sender.tag)
    }
}
#endif
