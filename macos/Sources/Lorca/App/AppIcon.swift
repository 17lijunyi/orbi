import AppKit
import ImageIO

/// The local app icon is independent of the account's bot avatars. A saved look is
/// rendered again at launch; imported artwork lives outside the signed app bundle.
@MainActor
enum AppIcon {
    static let didChange = Notification.Name("orbi.appIcon.didChange")

    private static let preferenceKey = "orbi.appIcon.selection.v1"

    private struct Selection: Codable {
        var configuration: PlushAvatar.Configuration
        var importedFileName: String?
    }

    private static var selection: Selection {
        guard let data = UserDefaults.standard.data(forKey: preferenceKey),
            let value = try? JSONDecoder().decode(Selection.self, from: data)
        else { return Selection(configuration: .init()) }
        return value
    }

    static var configuration: PlushAvatar.Configuration { selection.configuration.normalized }

    /// A persistent copy, suitable for reopening the editor after its source file moved.
    static var importedImageURL: URL? {
        guard let name = selection.importedFileName,
            name.hasSuffix(".png"), UUID(uuidString: String(name.dropLast(4))) != nil,
            let directory = try? supportDirectory(),
            FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
        else { return nil }
        return directory.appendingPathComponent(name)
    }

    static func make(size: CGFloat = 512) -> NSImage {
        let image: NSImage?
        if let url = importedImageURL, let imported = NSImage(contentsOf: url) {
            image = imported
        } else {
            image = PlushAvatar.image(for: configuration, side: 900)
        }
        // PlushAvatar caches its images; resizing a copy leaves other previews untouched.
        let result = (image?.copy() as? NSImage) ?? bundledImage()
            ?? NSImage(size: NSSize(width: size, height: size))
        result.size = NSSize(width: size, height: size)
        return result
    }

    static func apply() {
        NSApp.applicationIconImage = make()
    }

    /// Commit one encoded selection only after its artwork is usable. Passing no import
    /// switches back to the editable plush look and removes the previous local import.
    static func save(configuration: PlushAvatar.Configuration, importedImageURL: URL? = nil) throws {
        let normalized = configuration.normalized
        let previousImport = self.importedImageURL
        let importName = importedImageURL.map { _ in UUID().uuidString + ".png" }
        let value = Selection(configuration: normalized, importedFileName: importName)
        let encoded = try JSONEncoder().encode(value)

        if let importedImageURL, let importName {
            let png = try importedPNG(at: importedImageURL)
            let directory = try supportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: directory.appendingPathComponent(importName), options: .atomic)
        } else if PlushAvatar.image(for: normalized, side: 900) == nil {
            throw PlushAvatar.RenderError.missingArtwork
        }

        UserDefaults.standard.set(encoded, forKey: preferenceKey)
        apply()
        NotificationCenter.default.post(name: didChange, object: nil)
        if let previousImport { try? FileManager.default.removeItem(at: previousImport) }
    }

    private static func supportDirectory() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "app.lorca", isDirectory: true)
            .appendingPathComponent("AppIcon", isDirectory: true)
    }

    private enum ImportError: LocalizedError {
        case unreadableImage
        var errorDescription: String? { "无法读取这张图片，请选择其他图片后重试。" }
    }

    /// Decode at icon resolution and preserve the complete image's aspect ratio.
    private static func importedPNG(at url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 900,
            ] as CFDictionary),
            let context = CGContext(
                data: nil, width: 900, height: 900, bitsPerComponent: 8, bytesPerRow: 900 * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw ImportError.unreadableImage }
        let scale = min(900 / CGFloat(image.width), 900 / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (900 - size.width) / 2, y: (900 - size.height) / 2, width: size.width, height: size.height))
        guard let cgImage = context.makeImage(),
            let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        else { throw ImportError.unreadableImage }
        return data
    }

    private static func bundledImage() -> NSImage? {
        let iconFile = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String
            ?? "Orbi.icns"
        let resource = iconFile as NSString
        guard let url = Bundle.main.url(
            forResource: resource.deletingPathExtension,
            withExtension: resource.pathExtension.isEmpty ? "icns" : resource.pathExtension
        ),
            let image = NSImage(contentsOf: url)
        else { return nil }
        return image
    }
}
