#!/usr/bin/env bash
#
# Generates Resources/AppIcon.icns for the ClickShot Dock / Finder icon.
#
# The "Capture C" mark is rendered in Core Graphics (mirroring
# logo/logo-capture-c-icon.svg) at every iconset size, then packed with
# iconutil. Re-run this whenever the icon design changes.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUT="$ROOT/Resources/AppIcon.icns"
mkdir -p "$ICONSET" "$ROOT/Resources"

swift - "$ICONSET" <<'SWIFT'
import AppKit

let iconset = CommandLine.arguments[1]
let specs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

// Everything is laid out in a 1024-unit design space (CG origin = bottom-left).
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024.0
    ctx.scaleBy(x: s, y: s)

    // Squircle tile (824px art centred on the 1024 canvas).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: cs,
                          colors: [CGColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1),
                                   CGColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    // Top (high y) lighter, bottom darker.
    ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // "Capture C" glyph in white. Design centre (512,512), ring radius 240.
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(60)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    // Open ring: gap of ±38° on the right.
    ctx.addArc(center: CGPoint(x: 512, y: 512), radius: 240,
               startAngle: 38 * .pi / 180, endAngle: 322 * .pi / 180, clockwise: false)
    ctx.strokePath()
    // Crosshair: ±75 units (2.5 * 30) around centre.
    ctx.move(to: CGPoint(x: 512, y: 512 - 75)); ctx.addLine(to: CGPoint(x: 512, y: 512 + 75))
    ctx.move(to: CGPoint(x: 512 - 75, y: 512)); ctx.addLine(to: CGPoint(x: 512 + 75, y: 512))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in specs {
    try! render(px).write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
SWIFT

iconutil -c icns -o "$OUT" "$ICONSET"
rm -rf "$(dirname "$ICONSET")"
echo "Built: $OUT"
