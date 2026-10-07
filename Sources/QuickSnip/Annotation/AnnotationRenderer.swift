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
        case .rectangle(let rect):
            context.setLineJoin(.miter)
            context.stroke(rect)

        case .line(let from, let to):
            strokePolyline([from, to], width: width, in: context)

        case .arrow(let from, let to):
            drawArrow(from: from, to: to, width: width, in: context)

        case .pen(let points):
            strokePolyline(points, width: width, in: context)

        case .marker(let points):
            context.setAlpha(Annotation.markerAlpha)
            strokePolyline(points, width: width, in: context)

        case .text(let string, let origin):
            drawText(string, at: origin, style: annotation.style, in: context)

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

    private static func drawArrow(from: CGPoint, to: CGPoint, width: CGFloat, in context: CGContext) {
        let length = Geometry.distance(from, to)
        guard length > 0 else { return }
        let head = min(arrowHeadLength(for: width), length)
        let ux = (to.x - from.x) / length, uy = (to.y - from.y) / length
        let base = CGPoint(x: to.x - ux * head, y: to.y - uy * head)
        let halfWidth = head * 0.45

        // Stop the shaft inside the head so the round cap doesn't poke through the tip.
        let shaftEnd = CGPoint(x: base.x + ux * min(width, head / 2), y: base.y + uy * min(width, head / 2))
        strokePolyline([from, shaftEnd], width: width, in: context)

        context.beginPath()
        context.move(to: to)
        context.addLine(to: CGPoint(x: base.x - uy * halfWidth, y: base.y + ux * halfWidth))
        context.addLine(to: CGPoint(x: base.x + uy * halfWidth, y: base.y - ux * halfWidth))
        context.closePath()
        context.fillPath()
    }

    private static func drawText(_ string: String, at origin: CGPoint, style: AnnotationStyle, in context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        Annotation.attributedText(string, style: style).draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawPixelated(_ rect: CGRect, in context: CGContext, display: CapturedDisplay, cache: PixelateCache) {
        guard let pixelRect = CropMath.pixelRect(for: rect, in: display),
              let image = cache.image(for: display, pixelRect: pixelRect) else { return }

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
