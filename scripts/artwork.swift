// Draws the app's artwork from Sources/PapoReto/ProfileGlyph.swift, compiled with it by make, so every image shares one drawing:
// icns writes the app icon, the listening profile on the Grafite squircle of papo-reto-docs/design/icone/previa.html;
// showcase writes the README and social preview PNGs, committed in assets/ because GitHub serves them from the repo.
import AppKit

@main
enum Artwork {
    static func main() throws {
        let args = CommandLine.arguments
        let output = args.count == 3 ? URL(fileURLWithPath: args[2]) : nil
        switch (args.count == 3 ? args[1] : nil, output) {
        case ("icns", let output?): try icns(output)
        case ("showcase", let output?): try showcase(output)
        default:
            FileHandle.standardError.write(Data("usage: artwork icns <AppIcon.icns> | artwork showcase <dir>\n".utf8))
            exit(2)
        }
    }

    static func showcase(_ dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try iconPNG(pixels: 256).write(to: dir.appendingPathComponent("icon.png"))
        try menuBarPNG(dark: false).write(to: dir.appendingPathComponent("menu-bar-light.png"))
        try menuBarPNG(dark: true).write(to: dir.appendingPathComponent("menu-bar-dark.png"))
        try socialPreviewPNG().write(to: dir.appendingPathComponent("social-preview.png"))
    }

    /// The three profile states, each on a piece of menu bar with its name below, at 2x for Retina.
    static func menuBarPNG(dark: Bool) -> Data {
        let states: [(ProfileGlyph.Mark, String)] = [(.none, "Ready"), (.waves, "Listening"), (.dots, "Thinking")]
        let cell: CGFloat = 120, bar = NSRect(x: 30, y: 4, width: 60, height: 26)
        return png(width: Int(cell) * states.count, height: 60, scale: 2) {
            for (index, (mark, name)) in states.enumerated() {
                let x = CGFloat(index) * cell
                rgb(dark ? 0x2c2d30 : 0xebebed).setFill()
                NSBezierPath(roundedRect: bar.offsetBy(dx: x, dy: 0), xRadius: 7, yRadius: 7).fill()
                // The menu bar's 18 pt glyph, centered on the bar.
                let scale = 18 / ProfileGlyph.viewBox.height
                NSGraphicsContext.saveGraphicsState()
                let glyph = NSAffineTransform()
                glyph.translateX(by: x + cell / 2 - ProfileGlyph.viewBox.width * scale / 2, yBy: bar.midY - 9)
                glyph.scale(by: scale)
                glyph.translateX(by: -ProfileGlyph.viewBox.minX, yBy: -ProfileGlyph.viewBox.minY)
                glyph.concat()
                let ink = rgb(dark ? 0xf5f5f7 : 0x1d1d1f)
                ProfileGlyph.draw(mark, head: ink, wave: ink)
                NSGraphicsContext.restoreGraphicsState()
                text(name, centeredAt: x + cell / 2, top: 38, font: .systemFont(ofSize: 13, weight: .medium),
                     color: rgb(dark ? 0x9198a1 : 0x59636e))
            }
        }
    }

    /// GitHub's 1280 × 640 card for shared links, content inside its 40 pt safe border.
    static func socialPreviewPNG() -> Data {
        png(width: 1280, height: 640, scale: 1) {
            NSGradient(starting: rgb(0x2b2e33), ending: rgb(0x16181b))!.draw(in: NSRect(x: 0, y: 0, width: 1280, height: 640), angle: 90)
            NSGraphicsContext.saveGraphicsState()
            let icon = NSAffineTransform()
            icon.translateX(by: 70, yBy: 130)
            icon.scale(by: 380 / 1024)
            icon.concat()
            drawIcon()
            NSGraphicsContext.restoreGraphicsState()
            text("Papo Reto", left: 500, top: 196, font: .systemFont(ofSize: 104, weight: .bold), color: rgb(0xf3efe6))
            text("Voice dictation for macOS in", left: 504, top: 342, font: .systemFont(ofSize: 40), color: rgb(0xc9c4ba))
            text("Brazilian Portuguese. 100% local.", left: 504, top: 394, font: .systemFont(ofSize: 40), color: rgb(0xc9c4ba))
        }
    }

    static func text(_ string: String, centeredAt x: CGFloat, top: CGFloat, font: NSFont, color: NSColor) {
        let width = NSAttributedString(string: string, attributes: [.font: font]).size().width
        text(string, left: x - width / 2, top: top, font: font, color: color)
    }

    /// One line whose box starts at top, unflipped locally so the glyphs stand upright in the y-down canvas.
    static func text(_ string: String, left: CGFloat, top: CGFloat, font: NSFont, color: NSColor) {
        let line = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        NSGraphicsContext.saveGraphicsState()
        let upright = NSAffineTransform()
        upright.translateX(by: left, yBy: top + line.size().height)
        upright.scaleX(by: 1, yBy: -1)
        upright.concat()
        line.draw(at: .zero)
        NSGraphicsContext.restoreGraphicsState()
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
