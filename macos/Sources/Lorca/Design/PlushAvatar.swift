import AppKit
import ImageIO

/// The planet's fur and orbit are one transparent image; face and accessories are aligned
/// transparent layers. The attachment name keeps the editable look with its encrypted PNG.
enum PlushAvatar {
    struct Option: Hashable {
        let id: String
        let title: String
    }

    struct ColorOption: Hashable {
        let hex: String
        let title: String
    }

    enum Category: String {
        case eyes, glasses, accessory
    }

    static let eyeOptions = [
        Option(id: "lashes", title: "睫毛"), Option(id: "oval", title: "豆豆眼"),
        Option(id: "sparkle", title: "星星眼"), Option(id: "tall", title: "长眼睛"),
        Option(id: "dots", title: "小圆点"), Option(id: "round", title: "圆眼睛"),
        Option(id: "googly", title: "好奇"), Option(id: "sleepy", title: "困困"),
    ]

    static let glassesOptions = [
        Option(id: "none", title: "无眼镜"), Option(id: "monocle", title: "单片眼镜"),
        Option(id: "round", title: "圆框眼镜"), Option(id: "square", title: "方形墨镜"),
        Option(id: "classic", title: "经典墨镜"), Option(id: "shades", title: "圆形墨镜"),
    ]

    static let accessoryOptions = [
        Option(id: "none", title: "无配饰"), Option(id: "headphones", title: "耳机"),
        Option(id: "bowtie", title: "领结"), Option(id: "bowler", title: "圆顶帽"),
        Option(id: "tophat", title: "高顶礼帽"), Option(id: "beret", title: "贝雷帽"),
        Option(id: "pompom", title: "绒球"), Option(id: "tuft", title: "小呆毛"),
        Option(id: "crown", title: "皇冠"),
    ]

    static let palette = [
        ColorOption(hex: "#f667ad", title: "粉红"), ColorOption(hex: "#d862da", title: "兰紫"),
        ColorOption(hex: "#9d53f7", title: "紫色"), ColorOption(hex: "#4671fa", title: "蓝色"),
        ColorOption(hex: "#05adeb", title: "天蓝"), ColorOption(hex: "#05b89f", title: "青绿"),
        ColorOption(hex: "#b4d500", title: "青柠"), ColorOption(hex: "#ffd03e", title: "黄色"),
        ColorOption(hex: "#ff7a63", title: "珊瑚"),
    ]

    static let componentPalette = palette + [
        ColorOption(hex: "#222222", title: "黑色"), ColorOption(hex: "#914d2d", title: "棕色"),
    ]

    struct Configuration: Codable, Hashable {
        var color: String
        var eyes: String
        var glasses: String
        var accessory: String
        var glassesColor: String
        var accessoryColor: String

        init(
            color: String = "#f667ad", eyes: String = "sparkle", glasses: String = "none",
            accessory: String = "none", glassesColor: String = "#222222", accessoryColor: String = "#222222"
        ) {
            self.color = color
            self.eyes = eyes
            self.glasses = glasses
            self.accessory = accessory
            self.glassesColor = glassesColor
            self.accessoryColor = accessoryColor
        }

        /// The index order is part of the v1 attachment format; append options rather than
        /// reordering them. Eye index 8 is the bare planet used in the shape picker.
        private static let eyeIDs = PlushAvatar.eyeOptions.map(\.id) + ["none"]
        private static let glassesIDs = PlushAvatar.glassesOptions.map(\.id)
        private static let accessoryIDs = PlushAvatar.accessoryOptions.map(\.id)

        var normalized: Configuration {
            Configuration(
                color: PlushAvatar.normalizedHex(color) ?? "#f667ad",
                eyes: Self.eyeIDs.contains(eyes) ? eyes : "sparkle",
                glasses: Self.glassesIDs.contains(glasses) ? glasses : "none",
                accessory: Self.accessoryIDs.contains(accessory) ? accessory : "none",
                glassesColor: PlushAvatar.normalizedHex(glassesColor) ?? "#222222",
                accessoryColor: PlushAvatar.normalizedHex(accessoryColor) ?? "#222222"
            )
        }

        var fileName: String {
            let value = normalized
            let eyeIndex = Self.eyeIDs.firstIndex(of: value.eyes) ?? 2
            let glassesIndex = Self.glassesIDs.firstIndex(of: value.glasses) ?? 0
            let accessoryIndex = Self.accessoryIDs.firstIndex(of: value.accessory) ?? 0
            return "orbi-plush-v1-\(value.color.dropFirst())-\(eyeIndex)-\(glassesIndex)-\(accessoryIndex)-\(value.glassesColor.dropFirst())-\(value.accessoryColor.dropFirst()).png"
        }

        init?(fileName: String) {
            guard fileName.count < 128, fileName.lowercased().hasSuffix(".png") else { return nil }
            let parts = fileName.lowercased().dropLast(4).split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 9, parts[0] == "orbi", parts[1] == "plush", parts[2] == "v1",
                parts[3].count == 6, let color = PlushAvatar.normalizedHex(String(parts[3])),
                let eyeIndex = Int(parts[4]), Self.eyeIDs.indices.contains(eyeIndex),
                let glassesIndex = Int(parts[5]), Self.glassesIDs.indices.contains(glassesIndex),
                let accessoryIndex = Int(parts[6]), Self.accessoryIDs.indices.contains(accessoryIndex),
                parts[7].count == 6, let glassesColor = PlushAvatar.normalizedHex(String(parts[7])),
                parts[8].count == 6, let accessoryColor = PlushAvatar.normalizedHex(String(parts[8]))
            else { return nil }
            self.init(
                color: color, eyes: Self.eyeIDs[eyeIndex], glasses: Self.glassesIDs[glassesIndex],
                accessory: Self.accessoryIDs[accessoryIndex], glassesColor: glassesColor,
                accessoryColor: accessoryColor
            )
        }
    }

    static func configuration(for bot: Bot) -> Configuration {
        if let name = bot.avatar?.name, let saved = Configuration(fileName: name) { return saved }
        return defaultConfiguration(symbolName: bot.symbolName, accent: bot.accent)
    }

    /// Existing symbol avatars start with the selected pink, starry-eyed Orbi design.
    static func defaultConfiguration(symbolName: String, accent: Accent) -> Configuration {
        Configuration()
    }

    static func normalizedHex(_ value: String) -> String? {
        let value = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard value.utf8.count == 6,
            value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
        else { return nil }
        return "#" + value.lowercased()
    }

    @MainActor private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    private final class LayerImage: NSObject {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    @MainActor private static let layerCache: NSCache<NSString, LayerImage> = {
        let cache = NSCache<NSString, LayerImage>()
        cache.totalCostLimit = 36 * 1024 * 1024
        return cache
    }()

    /// The returned bitmap has transparent corners and retains the complete orbit.
    @MainActor
    static func image(for configuration: Configuration, side: Int = 900) -> NSImage? {
        let configuration = configuration.normalized
        let side = min(900, max(16, side))
        let key = "\(side)-\(configuration.fileName)" as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let base = layer(name: "base", color: configuration.color, isFur: true),
            let context = context(side: side)
        else { return nil }
        context.interpolationQuality = .high
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        context.draw(base, in: bounds)
        let components: [(String, String, String?)] = [
            ("eyes", configuration.eyes, nil),
            ("glasses", configuration.glasses, configuration.glassesColor),
            ("accessory", configuration.accessory, configuration.accessoryColor),
        ]
        for (category, kind, color) in components where kind != "none" {
            guard let component = layer(name: "\(category)/\(kind)", color: color) else { return nil }
            context.draw(component, in: bounds)
        }
        guard let cgImage = context.makeImage() else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
        imageCache.setObject(image, forKey: key, cost: side * side * 4)
        return image
    }

    @MainActor
    static func thumbnail(category: Category, kind: String, color: String = "#222222", side: Int = 180) -> NSImage? {
        var configuration = Configuration(color: "#f5eddf", eyes: "none", glasses: "none", accessory: "none")
        switch category {
        case .eyes: configuration.eyes = kind
        case .glasses:
            configuration.glasses = kind
            configuration.glassesColor = color
        case .accessory:
            configuration.accessory = kind
            configuration.accessoryColor = color
        }
        return image(for: configuration, side: side)
    }

    enum RenderError: LocalizedError {
        case missingArtwork
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .missingArtwork: "毛绒头像素材未能加载，请重新打开应用后再试。"
            case .encodingFailed: "头像图片未能保存，请重试。"
            }
        }
    }

    /// Uses the regular avatar attachment flow. A unique directory prevents two open editors
    /// from overwriting an attachment while the CLI reads it; the filename itself stays stable.
    @MainActor
    static func writePNG(for configuration: Configuration, side: Int = 512) throws -> URL {
        guard let image = image(for: configuration, side: side),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw RenderError.missingArtwork }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.encodingFailed }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbiPlushAvatars", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(configuration.fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func context(side: Int) -> CGContext? {
        CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
    }

    @MainActor
    private static func layer(name: String, color: String?, isFur: Bool = false) -> CGImage? {
        let key = "\(name)-\(color ?? "original")" as NSString
        if let cached = layerCache.object(forKey: key) { return cached.image }
        guard let root = Bundle.main.resourceURL,
            let source = CGImageSourceCreateWithURL(
                root.appendingPathComponent("PlushAvatars").appendingPathComponent(name + ".png") as CFURL, nil
            ), let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        if color == nil || (!isFur && color == "#222222") {
            layerCache.setObject(LayerImage(image), forKey: key, cost: image.width * image.height * 4)
            return image
        }

        guard let hex = color.flatMap(normalizedHex), let rgb = UInt32(hex.dropFirst(), radix: 16),
            let context = context(side: 900), let bytes = context.data?.assumingMemoryBound(to: UInt8.self)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 900, height: 900))
        let target = [Double((rgb >> 16) & 255), Double((rgb >> 8) & 255), Double(rgb & 255)]
        for pixel in stride(from: 0, to: 900 * 900 * 4, by: 4) {
            let alpha = Double(bytes[pixel + 3]) / 255
            guard alpha > 0 else { continue }
            // Core Graphics stores premultiplied pixels. Work with straight RGB like the
            // editor's canvas, then restore premultiplication so fur edges stay translucent.
            let red = Double(bytes[pixel]) / alpha
            let green = Double(bytes[pixel + 1]) / alpha
            let blue = Double(bytes[pixel + 2]) / alpha
            let shade = isFur
                ? pow((0.2126 * red + 0.7152 * green + 0.0722 * blue) / 229, 1.1)
                : max(0.32, min(1.2, (red + green + blue) / 105))
            for channel in 0..<3 {
                let value = min(255, (12 + target[channel] * (isFur ? 0.94 : 0.9)) * shade)
                bytes[pixel + channel] = UInt8(max(0, min(255, (value * alpha).rounded())))
            }
        }
        guard let tinted = context.makeImage() else { return nil }
        layerCache.setObject(LayerImage(tinted), forKey: key, cost: 900 * 900 * 4)
        return tinted
    }
}
