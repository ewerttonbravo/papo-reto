// Writes the app icon (.icns): the listening profile on the Grafite squircle of papo-reto-docs/design/icone/previa.html.
// Built by make with Sources/PapoReto/ProfileGlyph.swift, so the menu bar and the app share one drawing.
import AppKit

@main
enum AppIcon {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            print("usage: app-icon <AppIcon.icns>")
            exit(2)
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let iconset = output.deletingPathExtension().appendingPathExtension("iconset")
        try? FileManager.default.removeItem(at: iconset)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: iconset) }
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                try png(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
            }
        }
        let iconutil = try Process.run(URL(fileURLWithPath: "/usr/bin/iconutil"), arguments: ["-c", "icns", "-o", output.path, iconset.path])
        iconutil.waitUntilExit()
        // A throw, unlike exit(), still runs the defer that removes the iconset.
        if iconutil.terminationStatus != 0 { throw CocoaError(.fileWriteUnknown) }
    }

    /// The preview's 1024 canvas, y down: the macOS 824 grid squircle and the figure scaled into it.
    static func png(pixels: Int) throws -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!.retagging(with: .sRGB)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let canvas = NSAffineTransform()
        canvas.translateX(by: 0, yBy: CGFloat(pixels))
        canvas.scaleX(by: CGFloat(pixels) / 1024, yBy: -CGFloat(pixels) / 1024)
        canvas.concat()

        let squircle = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
        // Angle 90 runs from the top in this y-down space.
        NSGradient(starting: rgb(0x454a52), ending: rgb(0x1f2226))!.draw(in: squircle, angle: 90)
        let figure = NSAffineTransform()
        figure.translateX(by: 228, yBy: 268)
        figure.scale(by: 5.6)
        figure.concat()
        ProfileGlyph.draw(.waves, head: rgb(0xf3efe6), wave: rgb(0xff7a59))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])!
    }

    static func rgb(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}
