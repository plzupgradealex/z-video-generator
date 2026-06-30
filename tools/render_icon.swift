// App icon generator for Z Video Generator.
// Renders a 1024x1024 PNG: indigo→violet gradient + white play glyph + sparkles.
//
// Run:   swift tools/render_icon.swift Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png
// Then:  xcodebuild ... build   (the asset catalog picks up the new PNG)
//
// Tweak the gradient colors, glyph, or sparkle positions below and re-run.

import AppKit
import CoreGraphics
import ImageIO
import Foundation

let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()

func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

// Background: diagonal gradient indigo #6366f1 -> violet #a855f7
let grad = CGGradient(colorsSpace: cs,
                      colors: [col(0.388, 0.400, 0.945), col(0.659, 0.333, 0.969)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// Soft white glow disc behind the glyph
ctx.setFillColor(col(1, 1, 1, 0.10))
ctx.fillEllipse(in: CGRect(x: S * 0.16, y: S * 0.16, width: S * 0.68, height: S * 0.68))

// Bold white play triangle
ctx.setFillColor(col(1, 1, 1, 0.97))
ctx.beginPath()
ctx.move(to: CGPoint(x: S * 0.40, y: S * 0.32))
ctx.addLine(to: CGPoint(x: S * 0.40, y: S * 0.68))
ctx.addLine(to: CGPoint(x: S * 0.72, y: S * 0.50))
ctx.closePath()
ctx.fillPath()

// 4-point sparkle (concave diamond star)
func drawSparkle(center: CGPoint, outer: CGFloat, inner: CGFloat, alpha: Double) {
    let path = CGMutablePath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 - .pi / 2
        let r = (i % 2 == 0) ? outer : inner
        let p = CGPoint(x: center.x + r * CGFloat(cos(angle)),
                        y: center.y + r * CGFloat(sin(angle)))
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    ctx.setFillColor(col(1, 1, 1, alpha))
    ctx.addPath(path)
    ctx.fillPath()
}
drawSparkle(center: CGPoint(x: S * 0.80, y: S * 0.78), outer: S * 0.075, inner: S * 0.022, alpha: 0.95)
drawSparkle(center: CGPoint(x: S * 0.22, y: S * 0.24), outer: S * 0.045, inner: S * 0.014, alpha: 0.80)

guard let cgImage = ctx.makeImage() else { exit(2) }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else { exit(3) }
try! pngData.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1])")
