import AppKit

/// Modifier keys that change a drag, as in Figma and Preview: Shift constrains (square,
/// circle, 45° lines, a corner resize keeping proportions), Option draws a shape from its center.
struct DrawModifiers: Equatable, Sendable {
    var isConstrained = false
    var isFromCenter = false

    static let none = DrawModifiers()

    init(isConstrained: Bool = false, isFromCenter: Bool = false) {
        self.isConstrained = isConstrained
        self.isFromCenter = isFromCenter
    }

    init(_ flags: NSEvent.ModifierFlags) {
        self.init(isConstrained: flags.contains(.shift), isFromCenter: flags.contains(.option))
    }
}
