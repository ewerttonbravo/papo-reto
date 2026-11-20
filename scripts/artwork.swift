// Draws the app's artwork from Sources/PapoReto/ProfileGlyph.swift, compiled with it by make, so every image shares one drawing:
// icns writes the app icon, the listening profile on the Grafite squircle of papo-reto-docs/design/icone/previa.html.
import AppKit

@main
enum Artwork {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3, args[1] == "icns" else {
            print("usage: artwork icns <AppIcon.icns>")
            exit(2)
        }
        try icns(URL(fileURLWithPath: args[2]))
    }

    static func icns(_ output: URL) throws {
        let iconset = output.deletingPathExtension().appendingPathExtension("iconset")
        try? FileManager.default.removeItem(at: iconset)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: iconset) }
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                try iconPNG(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
            }
        }
        let iconutil = try Process.run(URL(fileURLWithPath: "/usr/bin/iconutil"), arguments: ["-c", "icns", "-o", output.path, iconset.path])
        iconutil.waitUntilExit()
        // A throw, unlike exit(), still runs the defer that removes the iconset.
        if iconutil.terminationStatus != 0 { throw CocoaError(.fileWriteUnknown) }
    }

    static func iconPNG(pixels: Int) -> Data {
        png(width: 1024, height: 1024, scale: CGFloat(pixels) / 1024, drawIcon)
    }

    /// The preview's 1024 canvas, y down: the macOS 824 grid squircle and the figure scaled into it.
    static func drawIcon() {
        let squircle = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
        // Angle 90 runs from the top in this y-down space.
        NSGradient(starting: rgb(0x454a52), ending: rgb(0x1f2226))!.draw(in: squircle, angle: 90)
        NSGraphicsContext.saveGraphicsState()
        let figure = NSAffineTransform()
        figure.translateX(by: 228, yBy: 268)
        figure.scale(by: 5.6)
        figure.concat()
        ProfileGlyph.draw(.waves, head: rgb(0xf3efe6), wave: rgb(0xff7a59))
        NSGraphicsContext.restoreGraphicsState()
    }

    /// An sRGB PNG of width × height points at scale pixels per point, drawn y down.
    static func png(width: Int, height: Int, scale: CGFloat, _ draw: () -> Void) -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(CGFloat(width) * scale), pixelsHigh: Int(CGFloat(height) * scale),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!.retagging(with: .sRGB)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let canvas = NSAffineTransform()
        canvas.translateX(by: 0, yBy: CGFloat(height) * scale)
        canvas.scaleX(by: scale, yBy: -scale)
        canvas.concat()
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])!
    }

    static func rgb(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}
