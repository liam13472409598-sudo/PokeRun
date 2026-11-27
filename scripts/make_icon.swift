// Generates the PokéRun app icon (a Poké Ball tile with a pixel Pikachu) as an .iconset.
// Usage: swift scripts/make_icon.swift <sprite.gif> <output.iconset>
import AppKit
import ImageIO

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: make_icon.swift <sprite.gif> <out.iconset>") }
let spriteURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let src = CGImageSourceCreateWithURL(spriteURL as CFURL, nil),
      let frame = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("cannot read sprite") }

// Crop to opaque bounds.
let w = frame.width, h = frame.height
var buf = [UInt8](repeating: 0, count: w * h * 4)
let bctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
bctx.draw(frame, in: CGRect(x: 0, y: 0, width: w, height: h))
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h { for x in 0..<w where buf[(y * w + x) * 4 + 3] > 8 {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
} }
let sprite = frame.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let inset = s * 0.09
    let tile = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = CGPath(roundedRect: tile, cornerWidth: tile.width * 0.22, cornerHeight: tile.width * 0.22, transform: nil)

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    // Bottom white, top red, black band + button (Poké Ball).
    ctx.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)); ctx.fill(tile)
    ctx.setFillColor(CGColor(red: 0.89, green: 0.16, blue: 0.18, alpha: 1))
    ctx.fill(CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2))
    let band = tile.height * 0.06
    ctx.setFillColor(CGColor(gray: 0.12, alpha: 1))
    ctx.fill(CGRect(x: tile.minX, y: tile.midY - band / 2, width: tile.width, height: band))
    let r = tile.width * 0.13
    ctx.fillEllipse(in: CGRect(x: tile.midX - r, y: tile.midY - r, width: r * 2, height: r * 2))
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    let r2 = r * 0.62
    ctx.fillEllipse(in: CGRect(x: tile.midX - r2, y: tile.midY - r2, width: r2 * 2, height: r2 * 2))
    ctx.restoreGState()

    // Pixel Pikachu, nearest-neighbour upscaled, sitting in the lower-right.
    let target = tile.width * 0.58
    let scale = target / CGFloat(max(sprite.width, sprite.height))
    let sw = CGFloat(sprite.width) * scale, sh = CGFloat(sprite.height) * scale
    ctx.interpolationQuality = .none
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.02, color: CGColor(gray: 0, alpha: 0.35))
    ctx.draw(sprite, in: CGRect(x: tile.maxX - sw - tile.width * 0.06, y: tile.minY + tile.height * 0.05, width: sw, height: sh))

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: outDir.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: outDir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print("iconset written to \(outDir.path)")
