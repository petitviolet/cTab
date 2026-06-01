#!/usr/bin/env swift
import AppKit

// cTab のアプリアイコンを生成するスクリプト。
// グラデーション背景 + 重なったウィンドウカード + ⌘ グリフでウィンドウ切替を表現する。
// 使い方: swift scripts/generate_icon.swift <出力 .iconset ディレクトリ>

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/cTab.iconset"

// MARK: - 描画

func drawIcon(into ctx: CGContext, size: CGFloat) {
    func s(_ v: CGFloat) -> CGFloat { v * size / 1024 }

    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradTop = NSColor(srgbRed: 0.42, green: 0.40, blue: 0.96, alpha: 1).cgColor
    let gradBottom = NSColor(srgbRed: 0.62, green: 0.36, blue: 0.90, alpha: 1).cgColor
    let glyphColor = NSColor(srgbRed: 0.36, green: 0.34, blue: 0.86, alpha: 1)

    // 背景の squircle
    let margin = s(64)
    let bgRect = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
    let bgCorner = bgRect.width * 0.2237
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: bgCorner, cornerHeight: bgCorner, transform: nil)

    // 影付きで下地を塗る
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: s(-16)), blur: s(40),
                  color: NSColor(white: 0, alpha: 0.25).cgColor)
    ctx.addPath(bgPath)
    ctx.setFillColor(gradBottom)
    ctx.fillPath()
    ctx.restoreGState()

    // グラデーション（上→下）
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: srgb, colors: [gradTop, gradBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: bgRect.midX, y: bgRect.maxY),
                           end: CGPoint(x: bgRect.midX, y: bgRect.minY),
                           options: [])
    ctx.restoreGState()

    // ウィンドウカード（CG は左下原点）
    let cardW = s(470)
    let cardH = s(330)
    let cardCorner = s(40)

    func cardPath(centerX: CGFloat, centerY: CGFloat) -> CGPath {
        let rect = CGRect(x: centerX - cardW / 2, y: centerY - cardH / 2, width: cardW, height: cardH)
        return CGPath(roundedRect: rect, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil)
    }

    // 背面カード（半透明・右上にずらす）
    ctx.saveGState()
    ctx.addPath(cardPath(centerX: size * 0.58, centerY: size * 0.585))
    ctx.setFillColor(NSColor(white: 1, alpha: 0.45).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // 前面カード（不透明・左下）
    let frontCX = size * 0.45
    let frontCY = size * 0.44
    let frontRect = CGRect(x: frontCX - cardW / 2, y: frontCY - cardH / 2, width: cardW, height: cardH)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: s(-6)), blur: s(18),
                  color: NSColor(white: 0, alpha: 0.18).cgColor)
    ctx.addPath(cardPath(centerX: frontCX, centerY: frontCY))
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // 前面カードのタイトルバーのドット（信号機色）
    let dotRadius = s(15)
    let dotY = frontRect.maxY - s(40)
    let dotStartX = frontRect.minX + s(44)
    let dotGap = s(46)
    let dotColors = [
        NSColor(srgbRed: 1.00, green: 0.37, blue: 0.34, alpha: 1),
        NSColor(srgbRed: 0.99, green: 0.74, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.16, green: 0.78, blue: 0.25, alpha: 1)
    ]
    for (i, color) in dotColors.enumerated() {
        let cx = dotStartX + CGFloat(i) * dotGap
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
    }

    // ⌘ グリフを前面カードのボディ中央に描く
    let glyph = "⌘" as NSString
    let font = NSFont.systemFont(ofSize: s(200), weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: glyphColor]
    let textSize = glyph.size(withAttributes: attrs)
    let bodyCenterY = frontRect.minY + (frontRect.height - s(70)) / 2
    let drawPoint = CGPoint(x: frontRect.midX - textSize.width / 2,
                            y: bodyCenterY - textSize.height / 2)
    glyph.draw(at: drawPoint, withAttributes: attrs)
}

// MARK: - 出力

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    drawIcon(into: gctx.cgContext, size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let entries: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for entry in entries {
    let rep = render(pixels: entry.px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    let path = "\(outputDir)/\(entry.name).png"
    try? data.write(to: URL(fileURLWithPath: path))
}

// プレビュー用 1024px PNG
if let data = render(pixels: 1024).representation(using: .png, properties: [:]) {
    try? data.write(to: URL(fileURLWithPath: "\(outputDir)/../cTab_preview.png"))
}

print("Generated icon set at \(outputDir)")
