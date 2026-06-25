import AppKit

/// Shared drawing for the selection overlays (both the press-and-drag overlay and
/// the interactive crosshair overlay).
enum SelectionRendering {
    /// How the area outside vs. inside the selection is rendered.
    enum OverlayStyle {
        /// Dim everything except the selection, which is shown as a clear hole.
        case dimSurroundings
        /// macOS screenshot look: leave the rest of the screen undimmed and tint
        /// only the selected area.
        case highlightSelection
    }

    /// The smallest rectangle (in AppKit global coordinates) containing all screens.
    static func unionFrame() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    /// The display a selection should be captured from: the screen sharing the
    /// largest area with `rect`. Using overlap area (rather than the selection's
    /// center) is robust when the center falls in a bezel gap between monitors.
    /// Falls back to the screen containing the center, then `NSScreen.main`.
    static func targetScreen(for rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        let best = screens.max { a, b in
            a.frame.intersection(rect).area < b.frame.intersection(rect).area
        }
        if let best, best.frame.intersection(rect).area > 0 { return best }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }

    /// Draws the selection according to `style`, plus its border and size label.
    ///
    /// - Parameters:
    ///   - selectionRect: selection in AppKit global coordinates.
    ///   - windowOrigin: the overlay window's origin in global coordinates.
    ///   - style: whether to dim the surroundings or tint the selection.
    ///   - drawsLabel: whether this overlay should draw the size/hint label. With
    ///     one overlay window per display, only the display owning the selection
    ///     draws the label so it isn't duplicated on every monitor.
    static func draw(in ctx: CGContext, bounds: CGRect, selectionRect: CGRect, windowOrigin: CGPoint, style: OverlayStyle, drawsLabel: Bool = true) {
        let local = CGRect(
            x: selectionRect.origin.x - windowOrigin.x,
            y: selectionRect.origin.y - windowOrigin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )

        switch style {
        case .dimSurroundings:
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
            ctx.fill(bounds)
            ctx.clear(local)
        case .highlightSelection:
            // No backdrop dim; a faint tint marks the selected area like macOS.
            guard selectionRect.width >= 1, selectionRect.height >= 1 else { break }
            ctx.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor)
            ctx.fill(local)
        }

        guard selectionRect.width >= 1, selectionRect.height >= 1 else { return }

        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(local.insetBy(dx: 0.75, dy: 0.75))

        if drawsLabel {
            drawSizeLabel(selectionRect: selectionRect, local: local, bounds: bounds)
        }
    }

    private static func drawSizeLabel(selectionRect: CGRect, local: CGRect, bounds: CGRect) {
        let sizeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75),
        ]
        let label = NSMutableAttributedString(
            string: "\(Int(selectionRect.width)) × \(Int(selectionRect.height))",
            attributes: sizeAttrs
        )
        label.append(NSAttributedString(
            string: "   Release to copy to clipboard · ⌘V to paste · Esc to cancel",
            attributes: hintAttrs
        ))

        let textSize = label.size()
        let padding: CGFloat = 6
        let boxSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding)

        var boxOrigin = CGPoint(x: local.minX, y: local.maxY + 6)
        if boxOrigin.y + boxSize.height > bounds.maxY {
            boxOrigin.y = local.maxY - boxSize.height - 6  // Flip below the top edge.
        }
        boxOrigin.x = max(bounds.minX, min(boxOrigin.x, bounds.maxX - boxSize.width))

        let box = CGRect(origin: boxOrigin, size: boxSize)
        let path = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.65).setFill()
        path.fill()

        label.draw(at: CGPoint(x: box.minX + padding, y: box.minY + padding / 2))
    }
}

private extension CGRect {
    /// Area of the rectangle, or 0 for a null/empty rect.
    var area: CGFloat { isNull ? 0 : width * height }
}
