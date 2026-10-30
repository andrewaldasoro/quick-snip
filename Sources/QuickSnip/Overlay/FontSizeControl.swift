import AppKit

/// Text size for the toolbar: a number field (typed values are parsed by `TextSize`) and a
/// stepper. Return or leaving the field applies; Esc or an invalid value puts the size back.
final class FontSizeControl: NSView, NSTextFieldDelegate {
    static let fieldWidth: CGFloat = 36
    static let spacing: CGFloat = 2

    private(set) var size: CGFloat
    private let onChange: @MainActor (CGFloat) -> Void
    let field = NSTextField(string: "")
    let stepper = NSStepper()

    init(size: CGFloat, onChange: @escaping @MainActor (CGFloat) -> Void) {
        self.size = size
        self.onChange = onChange
        super.init(frame: .zero)

        field.alignment = .right
        field.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.delegate = self
        field.target = self
        field.action = #selector(fieldAction(_:))
        field.toolTip = "Text size (px)"
        field.setAccessibilityLabel("Text size in pixels")

        let unit = NSTextField(labelWithString: "px")
        unit.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        unit.textColor = .secondaryLabelColor

        stepper.minValue = Double(TextSize.range.lowerBound)
        stepper.maxValue = Double(TextSize.range.upperBound)
        stepper.increment = Double(TextSize.step)
        stepper.valueWraps = false
        stepper.controlSize = .small
        stepper.target = self
        stepper.action = #selector(stepperAction(_:))
        stepper.toolTip = "Text size"
        stepper.setAccessibilityLabel("Text size")

        let row = NSStackView(views: [field, unit, stepper])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Self.spacing
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(equalToConstant: Self.fieldWidth),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: AnnotationToolbar.buttonSize.height),
        ])
        show(size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows `size`, unless the user is typing a new one.
    func update(size: CGFloat) {
        self.size = size
        guard field.currentEditor() == nil else { return }
        show(size)
    }

    private func show(_ size: CGFloat) {
        field.stringValue = String(Int(size))
        stepper.doubleValue = Double(size)
    }

    /// Applies the typed value. Reports only real changes, since ending the edit commits again.
    @discardableResult
    func commit() -> Bool {
        guard let parsed = TextSize.parse(field.stringValue) else {
            show(size)
            return false
        }
        show(parsed)
        guard parsed != size else { return false }
        size = parsed
        onChange(parsed)
        return true
    }

    /// Return always hands focus back to the overlay (through `onChange`), even when the size
    /// didn't change.
    @objc private func fieldAction(_ sender: NSTextField) {
        if !commit() { onChange(size) }
    }

    @objc private func stepperAction(_ sender: NSStepper) {
        let stepped = TextSize.clamp(CGFloat(sender.doubleValue))
        show(stepped)
        size = stepped
        onChange(stepped)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        commit()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        show(size)
        // Reapplying the current size hands focus back to the overlay, like any toolbar action.
        onChange(size)
        return true
    }
}
