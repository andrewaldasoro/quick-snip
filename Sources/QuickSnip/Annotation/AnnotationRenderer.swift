import AppKit

/// Draws annotations into a context whose user space is display-local points with a
/// top-left origin — the flipped overlay view, or the export context set up to match.
@MainActor
enum AnnotationRenderer {
    static func draw(_ annotations: [Annotation], in context: CGContext, display: CapturedDisplay, cache: PixelateCache) {
        for annotation in annotations {
            draw(annotation, in: context, display: display, cache: cache)
        }
    }

    static func draw(_ annotation: Annotation, in context: CGContext, display: CapturedDisplay, cache: PixelateCache) {
        context.saveGState()
        defer { context.restoreGState() }

        let color = annotation.style.color.cgColor
        let width = annotation.strokeWidth
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.kind {
        case .shape(let rect):
            drawShape(annotation.style.shape, in: rect, context: context)

        case .arrow(let from, let to):
            drawArrow(from: from, to: to, heads: annotation.style.arrowHeads, width: width, in: context)

        case .pen(let points):
            strokePolyline(points, width: width, in: context)

        case .marker(let points):
            context.setAlpha(Annotation.markerAlpha)
            strokePolyline(points, width: width, in: context)

        case .text(let string, let origin, let boxWidth):
            drawText(string, at: origin, boxWidth: boxWidth, style: annotation.style, in: context)

        case .pixelate(let rect):
            drawPixelated(rect, in: context, display: display, cache: cache)
        }
    }

    // MARK: Shapes

    private static func strokePolyline(_ points: [CGPoint], width: CGFloat, in context: CGContext) {
        guard let first = points.first else { return }
        if points.count == 1 {
            context.fillEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width))
            return
        }
        context.addLines(between: points)
        context.strokePath()
    }

    static func arrowHeadLength(for width: CGFloat) -> CGFloat {
        max(12, width * 4)
    }

    private static func drawShape(_ shape: ShapeKind, in rect: CGRect, context: CGContext) {
        switch shape {
        case .rectangle:
            context.setLineJoin(.miter)
            context.stroke(rect)
        case .oval:
            context.strokeEllipse(in: rect)
        }
    }

    /// Half the head's width at its base, as a fraction of its length.
    private static let headHalfWidthRatio: CGFloat = 0.45

    private static func drawArrow(from: CGPoint, to: CGPoint, heads: ArrowHeads, width: CGFloat, in context: CGContext) {
        let length = Geometry.distance(from, to)
        guard length > 0 else { return }
        // With two heads, each gets at most half the line.
        let head = min(arrowHeadLength(for: width), heads.hasStartHead ? length / 2 : length)
        // Stop the shaft inside each head so the round cap doesn't poke through the tip.
        let inset = head - min(width, head / 2)
        let shaftStart = heads.hasStartHead ? point(from, toward: to, by: inset) : from
        let shaftEnd = heads.hasEndHead ? point(to, toward: from, by: inset) : to
        strokePolyline([shaftStart, shaftEnd], width: width, in: context)
        if heads.hasEndHead { fillHead(at: to, from: from, length: head, in: context) }
        if heads.hasStartHead { fillHead(at: from, from: to, length: head, in: context) }
    }

    private static func point(_ origin: CGPoint, toward target: CGPoint, by distance: CGFloat) -> CGPoint {
        let length = Geometry.distance(origin, target)
        guard length > 0 else { return origin }
        return CGPoint(x: origin.x + (target.x - origin.x) * distance / length, y: origin.y + (target.y - origin.y) * distance / length)
    }

    /// A filled triangle with its tip at `tip`, pointing away from `tail`.
    private static func fillHead(at tip: CGPoint, from tail: CGPoint, length head: CGFloat, in context: CGContext) {
        let length = Geometry.distance(tail, tip)
        guard length > 0 else { return }
        let ux = (tip.x - tail.x) / length
        let uy = (tip.y - tail.y) / length
        let base = CGPoint(x: tip.x - ux * head, y: tip.y - uy * head)
        let halfWidth = head * headHalfWidthRatio
        context.beginPath()
        context.move(to: tip)
        context.addLine(to: CGPoint(x: base.x - uy * halfWidth, y: base.y + ux * halfWidth))
        context.addLine(to: CGPoint(x: base.x + uy * halfWidth, y: base.y - ux * halfWidth))
        context.closePath()
        context.fillPath()
    }

    private static func drawText(_ string: String, at origin: CGPoint, boxWidth: CGFloat?, style: AnnotationStyle, in context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        TextLayout.draw(string, origin: origin, boxWidth: boxWidth, style: style)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawPixelated(_ rect: CGRect, in context: CGContext, display: CapturedDisplay, cache: PixelateCache) {
        guard let pixelRect = CropMath.pixelRect(for: rect, in: display),
            let image = cache.image(for: display, pixelRect: pixelRect)
        else { return }

        let scaleX = display.pixelSize.width / display.frame.width
        let scaleY = display.pixelSize.height / display.frame.height
        let target = CGRect(
            x: pixelRect.minX / scaleX, y: pixelRect.minY / scaleY,
            width: pixelRect.width / scaleX, height: pixelRect.height / scaleY
        )

        // CGContext draws images bottom-up; flip around the target so it lands upright.
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: target.minY + target.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: target)
    }
}
