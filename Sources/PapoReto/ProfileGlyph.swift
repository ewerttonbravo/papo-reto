import AppKit

/// The "papo reto" profile, variant C of papo-reto-docs/design/icone/previa.html, in its SVG units (y down).
/// Shared with scripts/artwork.swift, so it imports AppKit only.
enum ProfileGlyph {
    enum Mark { case none, waves, dots }

    /// The preview's viewBox: the figure with its stroke and waves.
    static let viewBox = NSRect(x: 4, y: -2, width: 96, height: 90)

    /// Draws in viewBox units into a y-down context.
    static func draw(_ mark: Mark, head: NSColor, wave: NSColor) {
        let silhouette = NSBezierPath()
        silhouette.move(to: NSPoint(x: 32, y: 84))
        silhouette.line(to: NSPoint(x: 32, y: 70.5))
        silhouette.line(to: NSPoint(x: 25, y: 67.5))
        silhouette.curve(to: NSPoint(x: 9, y: 39), controlPoint1: NSPoint(x: 13, y: 61), controlPoint2: NSPoint(x: 8, y: 50))
        silhouette.curve(to: NSPoint(x: 48, y: 3), controlPoint1: NSPoint(x: 10, y: 18), controlPoint2: NSPoint(x: 28, y: 4))
        silhouette.curve(to: NSPoint(x: 78, y: 15), controlPoint1: NSPoint(x: 63, y: 3), controlPoint2: NSPoint(x: 75, y: 9))
        silhouette.curve(to: NSPoint(x: 80.5, y: 27), controlPoint1: NSPoint(x: 80, y: 19), controlPoint2: NSPoint(x: 80, y: 23))
        silhouette.curve(to: NSPoint(x: 91, y: 37.5), controlPoint1: NSPoint(x: 81, y: 31), controlPoint2: NSPoint(x: 84, y: 34))
        silhouette.line(to: NSPoint(x: 58, y: 60))
        silhouette.curve(to: NSPoint(x: 44, y: 84), controlPoint1: NSPoint(x: 50, y: 66), controlPoint2: NSPoint(x: 45, y: 74))
        silhouette.close()
        silhouette.lineWidth = 7
        silhouette.lineJoinStyle = .round
        NSGraphicsContext.saveGraphicsState()
        if mark == .dots {
            // Holes by geometry, not a .clear blend, which would erase whatever the image is drawn over.
            let holes = NSBezierPath(rect: viewBox)
            for x: CGFloat in [34, 48, 62] { holes.appendOval(in: NSRect(x: x - 5.5, y: 24 - 5.5, width: 11, height: 11)) }
            holes.windingRule = .evenOdd
            holes.addClip()
        }
        head.setFill()
        head.setStroke()
        silhouette.fill()
        silhouette.stroke()
        NSGraphicsContext.restoreGraphicsState()

        if mark == .waves {
            wave.setStroke()
            // The preview's three arcs share this center and sweep about -2° to 62°.
            for radius: CGFloat in [13, 22, 31] {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: NSPoint(x: 64, y: 56), radius: radius, startAngle: -2.2, endAngle: 62, clockwise: false)
                arc.lineWidth = 5.6
                arc.lineCapStyle = .round
                arc.stroke()
            }
        }
    }

    /// A template image at the menu bar's 18 pt, so it follows the light and dark bars.
    static func menuBarImage(_ mark: Mark) -> NSImage {
        let scale = 18 / viewBox.height
        // Whole points (the figure is 19.2 wide), so a 1x display does not resample the image.
        let width = (viewBox.width * scale).rounded(.up)
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: true) { _ in
            let transform = NSAffineTransform()
            transform.translateX(by: (width - viewBox.width * scale) / 2, yBy: 0)
            transform.scale(by: scale)
            transform.translateX(by: -viewBox.minX, yBy: -viewBox.minY)
            transform.concat()
            draw(mark, head: .black, wave: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Papo Reto"
        return image
    }
}
