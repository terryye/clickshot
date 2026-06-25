import AppKit

/// Shared drawing for the selection overlays (both the press-and-drag overlay and
/// the interactive crosshair overlay).
enum SelectionRendering {
    /// The smallest rectangle (in AppKit global coordinates) containing all screens.
    static func unionFrame() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    /// Draws the dimmed backdrop and, if a selection exists, the clear selection
    /// window, its border, and a size label.
    ///
    /// - Parameters:
    ///   - selectionRect: selection in AppKit global coordinates.
    ///   - windowOrigin: the overlay window's origin in global coordinates.
    ///   - dim: whether to dim the area outside the selection.
    static func draw(in ctx: CGContext, bounds: CGRect, selectionRect: CGRect, windowOrigin: CGPoint, dim: Bool) {
        let local = CGRect(
            x: selectionRect.origin.x - windowOrigin.x,
            y: selectionRect.origin.y - windowOrigin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )

        if dim {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
            ctx.fill(bounds)
            ctx.clear(local)
        }

        guard selectionRect.width >= 1, selectionRect.height >= 1 else { return }

        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(local.insetBy(dx: 0.75, dy: 0.75))

        drawSizeLabel(selectionRect: selectionRect, local: local, bounds: bounds)
    }

    private static func drawSizeLabel(selectionRect: CGRect, local: CGRect, bounds: CGRect) {
        let text = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let boxSize = CGSize(width: size.width + padding * 2, height: size.height + padding)

        var boxOrigin = CGPoint(x: local.minX, y: local.maxY + 6)
        if boxOrigin.y + boxSize.height > bounds.maxY {
            boxOrigin.y = local.maxY - boxSize.height - 6  // Flip below the top edge.
        }
        boxOrigin.x = max(bounds.minX, min(boxOrigin.x, bounds.maxX - boxSize.width))

        let box = CGRect(origin: boxOrigin, size: boxSize)
        let path = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.65).setFill()
        path.fill()

        text.draw(
            at: CGPoint(x: box.minX + padding, y: box.minY + padding / 2),
            withAttributes: attributes
        )
    }
}
