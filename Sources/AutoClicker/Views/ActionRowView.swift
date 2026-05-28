#if canImport(AppKit)
import AppKit

public final class ActionRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let pauseField = NSTextField(string: "")
    private let deleteButton = NSButton(title: "×", target: nil, action: nil)
    private var onDelete: (() -> Void)?
    private var onPauseUpdated: ((Int) -> Void)?

    public init(action: MacroAction, onDelete: @escaping () -> Void, onPauseUpdated: ((Int) -> Void)? = nil) {
        self.onDelete = onDelete
        self.onPauseUpdated = onPauseUpdated
        super.init(frame: .zero)
        configure(action: action)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(action: MacroAction) {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.stringValue = KeyFormatter.label(for: action)
        stack.addArrangedSubview(titleLabel)

        switch action {
        case let .pause(milliseconds):
            pauseField.stringValue = String(milliseconds)
            pauseField.alignment = .right
            pauseField.placeholderString = "ms"
            pauseField.target = self
            pauseField.action = #selector(commitPause)
            pauseField.widthAnchor.constraint(equalToConstant: 70).isActive = true
            stack.addArrangedSubview(pauseField)
        default:
            break
        }

        deleteButton.target = self
        deleteButton.action = #selector(deleteRow)
        deleteButton.isBordered = false
        deleteButton.font = .systemFont(ofSize: 16, weight: .bold)
        deleteButton.setAccessibilityLabel("Delete action")
        stack.addArrangedSubview(deleteButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 46)
        ])
    }

    @objc private func deleteRow() {
        onDelete?()
    }

    @objc private func commitPause() {
        guard let value = Int(pauseField.stringValue), value >= 0 else { return }
        onPauseUpdated?(value)
    }
}
#endif
