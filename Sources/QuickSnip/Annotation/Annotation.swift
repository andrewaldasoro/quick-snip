import AppKit

enum AnnotationTool: String, CaseIterable, Sendable {
    case rectangle, arrow, line, pen, marker, text, pixelate

    var displayName: String { rawValue.capitalized }
}

enum AnnotationColor: String, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple, black, white

    var displayName: String { rawValue.capitalized }

    var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        switch self {
        case .red: (1.00, 0.23, 0.19)
        case .orange: (1.00, 0.58, 0.00)
        case .yellow: (1.00, 0.80, 0.00)
        case .green: (0.20, 0.78, 0.35)
        case .blue: (0.00, 0.48, 1.00)
        case .purple: (0.69, 0.32, 0.87)
        case .black: (0.00, 0.00, 0.00)
        case .white: (1.00, 1.00, 1.00)
        }
    }

    var cgColor: CGColor {
        let c = components
        return CGColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
    }

    var nsColor: NSColor {
        let c = components
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
    }
}

struct AnnotationStyle: Equatable, Sendable {
    var color: AnnotationColor = .red
    /// Line thickness in points, for every kind but text and pixelate.
    var lineWidth: CGFloat = LineWidth.default
    /// Text annotations only.
    var font: TextFont = .system
    var fontSize: CGFloat = TextSize.default

    static let `default` = AnnotationStyle()
}

enum AnnotationKind: Equatable, Sendable {
    case rectangle(CGRect)
    case line(from: CGPoint, to: CGPoint)
    case arrow(from: CGPoint, to: CGPoint)
    case pen([CGPoint])
    case marker([CGPoint])
    case text(String, origin: CGPoint)
    case pixelate(CGRect)
}

/// A vector annotation in display-local points (top-left origin), the same space as the selection.
struct Annotation: Identifiable, Equatable, Sendable {
    static let markerWidthMultiplier: CGFloat = 4
    static let markerAlpha: CGFloat = 0.4

    let id: UUID
    var kind: AnnotationKind
    var style: AnnotationStyle

    init(id: UUID = UUID(), kind: AnnotationKind, style: AnnotationStyle) {
        self.id = id
        self.kind = kind
        self.style = style
    }

    var name: String {
        switch kind {
        case .rectangle: "Rectangle"
        case .line: "Line"
        case .arrow: "Arrow"
        case .pen: "Pen"
        case .marker: "Marker"
        case .text: "Text"
        case .pixelate: "Pixelate"
        }
    }

    /// Stroke width as drawn (the marker is wider than the nominal width).
    var strokeWidth: CGFloat {
        if case .marker = kind { return style.lineWidth * Self.markerWidthMultiplier }
        return style.lineWidth
    }

    @MainActor
    var bounds: CGRect {
        let half = strokeWidth / 2
        switch kind {
        case .rectangle(let rect):
            return rect.insetBy(dx: -half, dy: -half)
        case .pixelate(let rect):
            return rect
        case .line(let a, let b), .arrow(let a, let b):
            return Geometry.rect(from: a, to: b).insetBy(dx: -strokeWidth * 2, dy: -strokeWidth * 2)
        case .pen(let points), .marker(let points):
            return Geometry.boundingRect(of: points).insetBy(dx: -half, dy: -half)
        case .text(let string, let origin):
            return CGRect(origin: origin, size: Self.attributedText(string, style: style).size())
        }
    }

    @MainActor
    func hitTest(_ point: CGPoint, tolerance: CGFloat = 6) -> Bool {
        let reach = tolerance + strokeWidth / 2
        switch kind {
        case .rectangle(let rect):
            let outer = rect.insetBy(dx: -reach, dy: -reach)
            let inner = rect.insetBy(dx: reach, dy: reach)
            return outer.contains(point) && !(inner.width > 0 && inner.height > 0 && inner.contains(point))
        case .pixelate(let rect):
            return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .line(let a, let b), .arrow(let a, let b):
            return Geometry.distance(from: point, toSegment: a, b) <= reach
        case .pen(let points), .marker(let points):
            return Geometry.distance(from: point, toPolyline: points) <= reach
        case .text:
            return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    func offsetBy(dx: CGFloat, dy: CGFloat) -> Annotation {
        func move(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + dx, y: p.y + dy) }
        var moved = self
        switch kind {
        case .rectangle(let rect): moved.kind = .rectangle(rect.offsetBy(dx: dx, dy: dy))
        case .pixelate(let rect): moved.kind = .pixelate(rect.offsetBy(dx: dx, dy: dy))
        case .line(let a, let b): moved.kind = .line(from: move(a), to: move(b))
        case .arrow(let a, let b): moved.kind = .arrow(from: move(a), to: move(b))
        case .pen(let points): moved.kind = .pen(points.map(move))
        case .marker(let points): moved.kind = .marker(points.map(move))
        case .text(let string, let origin): moved.kind = .text(string, origin: move(origin))
        }
        return moved
    }

    @MainActor
    static func attributedText(_ string: String, style: AnnotationStyle) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: style.font.font(size: style.fontSize),
                .foregroundColor: style.color.nsColor,
            ])
    }
}
