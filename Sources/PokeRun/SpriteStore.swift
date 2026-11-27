import AppKit
import ImageIO

/// Decoded, cropped and menu-bar-scaled frames for one Pokémon.
struct RunnerFrames {
    let images: [NSImage]
    let flipped: [NSImage]
    let delays: [Double]
    let total: Double

    var count: Int { images.count }
}

/// Filter used in the Pokédex browser.
enum DexStyleFilter: Hashable, Identifiable {
    case all
    case series(SpriteStyle)

    static var allCases: [DexStyleFilter] {
        [.all] + SpriteStyle.allCases.map { .series($0) }
    }

    var id: String {
        switch self {
        case .all: return "all"
        case .series(let s): return s.rawValue
        }
    }

    var label: String {
        switch self {
        case .all: return "All"
        case .series(let s): return s.shortFilterLabel
        }
    }
}

/// Loads bundled pixel Pokémon sprites across all 5 series and Pokémon names.
final class SpriteStore {
    static let shared = SpriteStore()

    /// Standard height for battle sprites (B/W, Emerald, Crystal) in the menu bar, in points.
    static let battleMenuBarHeight: CGFloat = 20
    /// Max height for 2× integer-scaled mini pixel sprites (FireRed, HGSS) in the menu bar, in points.
    static let miniMenuBarMaxHeight: CGFloat = 22
    /// Widest a runner may be in the menu bar, in points.
    static let menuBarMaxWidth: CGFloat = 44

    let names: [String]
    private var frameCache: [String: RunnerFrames] = [:]
    private var thumbCache: [String: NSImage] = [:]

    private init() {
        if let url = Bundle.main.url(forResource: "names", withExtension: "json")
            ?? Self.devResourcesURL?.appendingPathComponent("names.json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            names = list
        } else {
            names = []
        }
    }

    private static var devResourcesURL: URL? {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        var dir = exe.deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("Resources/sprites")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return dir.appendingPathComponent("Resources")
            }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    // MARK: Names & Search

    func speciesName(_ dexID: Int) -> String {
        guard dexID >= 1, dexID <= names.count else { return "Pokémon #\(dexID)" }
        return names[dexID - 1]
    }

    func displayName(_ item: RunnerItem) -> String {
        let base = speciesName(item.dexID)
        switch item.style {
        case .blackWhite: return base
        case .fireRed, .hgss, .emerald, .crystal: return "\(base) (\(item.style.badge))"
        }
    }

    func subtitle(_ item: RunnerItem) -> String {
        "\(Self.dexNumber(item.dexID)) · \(item.style.badge)"
    }

    static func dexNumber(_ id: Int) -> String { String(format: "#%03d", id) }

    /// Searches Pokédex entries in series order: B/W -> FireRed -> HGSS -> Emerald -> Crystal.
    func search(_ query: String, filter: DexStyleFilter = .all) -> [RunnerItem] {
        let styles: [SpriteStyle]
        switch filter {
        case .all: styles = SpriteStyle.allCases
        case .series(let s): styles = [s]
        }

        let allItems = styles.flatMap { style in
            (1...style.maxID).map { RunnerItem(style: style, dexID: $0) }
        }

        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allItems }

        let numeric = q.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if let n = Int(numeric) {
            return allItems.filter { String($0.dexID).hasPrefix(String(n)) }
        }
        return allItems.filter { item in
            speciesName(item.dexID).lowercased().contains(q)
                || item.style.title.lowercased().contains(q)
                || item.style.badge.lowercased().contains(q)
        }
    }

    // MARK: Sprites

    func spriteURL(_ item: RunnerItem) -> URL? {
        let subdir = item.style.subdirectory
        let ext = item.style.fileExtension
        if let url = Bundle.main.url(forResource: "\(item.dexID)", withExtension: ext, subdirectory: subdir) {
            return url
        }
        if let dev = Self.devResourcesURL?.appendingPathComponent("\(subdir)/\(item.dexID).\(ext)"),
           FileManager.default.fileExists(atPath: dev.path) {
            return dev
        }
        return nil
    }

    /// Frames sized for the menu bar.
    func runnerFrames(for item: RunnerItem) -> RunnerFrames? {
        switch item.style {
        case .blackWhite, .emerald, .crystal:
            return frames(for: item, height: Self.battleMenuBarHeight, maxWidth: Self.menuBarMaxWidth, menuBarMode: true)
        case .fireRed, .hgss:
            return frames(for: item, height: Self.miniMenuBarMaxHeight, maxWidth: Self.menuBarMaxWidth, menuBarMode: true)
        }
    }

    /// Frames sized to an arbitrary point height (used for previews).
    func frames(for item: RunnerItem, height: CGFloat, maxWidth: CGFloat, menuBarMode: Bool = false) -> RunnerFrames? {
        let key = "\(item.key)@\(height)x\(maxWidth)m\(menuBarMode ? 1 : 0)"
        if let cached = frameCache[key] { return cached }
        guard let url = spriteURL(item),
              let decoded = Self.decodeSprite(url, style: item.style),
              let crop = Self.unionOpaqueBounds(decoded.frames) else { return nil }

        let images = decoded.frames.map {
            Self.render($0, crop: crop, style: item.style, height: height, maxWidth: maxWidth, flip: false, menuBarMode: menuBarMode)
        }
        let flipped = decoded.frames.map {
            Self.render($0, crop: crop, style: item.style, height: height, maxWidth: maxWidth, flip: true, menuBarMode: menuBarMode)
        }
        let result = RunnerFrames(images: images, flipped: flipped, delays: decoded.delays,
                                  total: decoded.delays.reduce(0, +))
        frameCache[key] = result
        return result
    }

    /// First frame, for lists and menus.
    func thumbnail(for item: RunnerItem, height: CGFloat = 28) -> NSImage? {
        let key = "\(item.key)@\(height)"
        if let cached = thumbCache[key] { return cached }
        guard let url = spriteURL(item),
              let decoded = Self.decodeSprite(url, style: item.style),
              let crop = Self.unionOpaqueBounds(decoded.frames),
              let first = decoded.frames.first else { return nil }
        let image = Self.render(first, crop: crop, style: item.style, height: height, maxWidth: height * 1.6, flip: false, menuBarMode: false)
        thumbCache[key] = image
        return image
    }

    // MARK: Decoding helpers

    private static func decodeSprite(_ url: URL, style: SpriteStyle) -> (frames: [CGImage], delays: [Double])? {
        switch style {
        case .blackWhite, .crystal:
            return decodeGIF(url)
        case .fireRed:
            return decodeVerticalTwoFrameSheet(url, frameDelay: 0.25)
        case .emerald:
            return decodeVerticalTwoFrameSheet(url, frameDelay: 0.28)
        case .hgss:
            return decodeHGSSOverworldSheet(url)
        }
    }

    /// Decodes a vertical 2-frame sprite sheet (FireRed 32×64 party icon or Emerald 64×128 battle sprite).
    private static func decodeVerticalTwoFrameSheet(_ url: URL, frameDelay: Double) -> (frames: [CGImage], delays: [Double])? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil),
              sheet.width > 0, sheet.height > 0 else { return nil }
        guard sheet.height >= sheet.width * 2 else {
            return ([sheet], [frameDelay])
        }
        let cellW = sheet.width
        let cellH = sheet.height / 2
        guard let f0 = sheet.cropping(to: CGRect(x: 0, y: 0, width: cellW, height: cellH)),
              let f1 = sheet.cropping(to: CGRect(x: 0, y: cellH, width: cellW, height: cellH)) else { return nil }
        return ([f0, f1], [frameDelay, frameDelay])
    }

    /// Decodes a horizontal HeartGold/SoulSilver overworld follower sheet, extracting the side-walking frames.
    private static func decodeHGSSOverworldSheet(_ url: URL) -> (frames: [CGImage], delays: [Double])? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil),
              sheet.width > 0, sheet.height > 0 else { return nil }
        let cells = max(1, sheet.width / sheet.height)
        let cellW = sheet.width / cells
        let cellH = sheet.height
        // Standard 6-cell HGSS sheet: [down0, down1, up0, up1, leftWalk0, leftWalk1].
        let i0: Int
        let i1: Int
        if cells >= 6 {
            i0 = 4; i1 = 5
        } else if cells >= 2 {
            i0 = cells - 2; i1 = cells - 1
        } else {
            i0 = 0; i1 = 0
        }
        guard let f0 = sheet.cropping(to: CGRect(x: i0 * cellW, y: 0, width: cellW, height: cellH)),
              let f1 = sheet.cropping(to: CGRect(x: i1 * cellW, y: 0, width: cellW, height: cellH)) else { return nil }
        return ([f0, f1], [0.22, 0.22])
    }

    private static func decodeGIF(_ url: URL) -> (frames: [CGImage], delays: [Double])? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(src)
        guard count > 0 else { return nil }
        var frames: [CGImage] = []
        var delays: [Double] = []
        for i in 0..<count {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            var delay = 0.1
            if let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                let d = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                    ?? (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
                delay = d < 0.011 ? 0.1 : d
            }
            frames.append(img)
            delays.append(delay)
        }
        return frames.isEmpty ? nil : (frames, delays)
    }

    /// Union of the non-transparent pixel bounds across all frames (top-left origin).
    private static func unionOpaqueBounds(_ frames: [CGImage]) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for img in frames {
            let w = img.width, h = img.height
            var buf = [UInt8](repeating: 0, count: w * h * 4)
            let ok: Bool = buf.withUnsafeMutableBytes { ptr in
                guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            guard ok else { continue }
            for y in 0..<h {
                let row = y * w * 4
                for x in 0..<w where buf[row + x * 4 + 3] > 8 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Crop and scale one frame. Upscales use nearest-neighbour so pixels stay razor-sharp.
    private static func render(_ img: CGImage, crop: CGRect, style: SpriteStyle,
                               height: CGFloat, maxWidth: CGFloat, flip: Bool, menuBarMode: Bool) -> NSImage {
        let backing: CGFloat = 2
        let targetH = height * backing
        let targetW = maxWidth * backing
        var scale = min(targetH / crop.height, targetW / crop.width)
        let crisp = scale >= 1

        if (style == .fireRed || style == .hgss) && menuBarMode {
            if crop.height * 2 <= targetH && crop.width * 2 <= targetW {
                scale = 2.0
            }
        } else if crisp {
            scale = max(1.0, floor(scale))
        }

        let outW = max(1, Int((crop.width * scale).rounded()))
        let outH = max(1, Int((crop.height * scale).rounded()))
        guard let cropped = img.cropping(to: crop),
              let ctx = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: NSSize(width: height, height: height))
        }
        ctx.interpolationQuality = crisp ? .none : .high
        if flip {
            ctx.translateBy(x: CGFloat(outW), y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: outW, height: outH))
        guard let out = ctx.makeImage() else { return NSImage(size: NSSize(width: height, height: height)) }
        let image = NSImage(cgImage: out, size: NSSize(width: CGFloat(outW) / backing, height: CGFloat(outH) / backing))
        image.isTemplate = false
        return image
    }
}
