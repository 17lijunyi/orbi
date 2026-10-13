import AppKit
import ImageIO
import UniformTypeIdentifiers

/// A file picked, dropped, or pasted into the composer, before the CLI stores it. The id is
/// minted here so the bubble the app shows right away and the CLI's copy agree.
struct OutgoingAttachment: Hashable {
    var attachment: Attachment
    var url: URL

    static let maxBytes = 100 * 1024 * 1024
    static let maxCount = 10

    enum Problem: LocalizedError {
        case notAFile(String)
        case tooLarge(String)

        var errorDescription: String? {
            switch self {
            case let .notAFile(name): L("%@ is not a file.", name)
            case let .tooLarge(name): L("%@ is larger than %d MB.", name, OutgoingAttachment.maxBytes / 1024 / 1024)
            }
        }
    }

    static func make(url: URL) throws -> OutgoingAttachment {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey])
        guard values.isRegularFile == true else { throw Problem.notAFile(url.lastPathComponent) }
        let size = values.fileSize ?? 0
        guard size <= maxBytes else { throw Problem.tooLarge(url.lastPathComponent) }
        let mime = values.contentType?.preferredMIMEType ?? "application/octet-stream"

        var width: Int?
        var height: Int?
        if mime.hasPrefix("image/"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        {
            width = properties[kCGImagePropertyPixelWidth] as? Int
            height = properties[kCGImagePropertyPixelHeight] as? Int
            // A rotated photo (EXIF orientation 5–8) is shown upright, so its box is too.
            if let orientation = properties[kCGImagePropertyOrientation] as? Int, orientation >= 5 {
                swap(&width, &height)
            }
        }

        let id = "att-" + (0..<6).map { _ in String(format: "%02x", Int.random(in: 0...255)) }.joined()
        let attachment = Attachment(id: id, name: url.lastPathComponent, mime: mime, size: size, width: width, height: height)
        return OutgoingAttachment(attachment: attachment, url: url)
    }

    /// Pasted image data becomes a PNG on disk the CLI can read.
    static func make(pastedPNG data: Data) throws -> OutgoingAttachment {
        // The display name can repeat within one second; the backing file must never do so.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lorca-paste", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = directory.appendingPathComponent("Pasted image \(formatter.string(from: Date())).png")
        do {
            try data.write(to: url, options: .atomic)
            return try make(url: url)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}

/// Downsampled images, cached separately for composer chips and transcript bubbles.
@MainActor
enum Thumbnails {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func image(at url: URL, maxPixels: Int) -> NSImage? {
        var currentURL = url
        currentURL.removeAllCachedResourceValues()
        guard maxPixels > 0,
            let file = try? currentURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        else { return nil }
        // A local file can be replaced after it was attached. Include its current revision as
        // well as size, so an old chip cannot mask either new bytes or a larger bubble preview.
        let key = "\(url.absoluteString)|\(maxPixels)|\(file.fileSize ?? 0)|\(file.contentModificationDate?.timeIntervalSince1970 ?? 0)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
