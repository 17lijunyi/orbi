import AppKit
import Foundation

// Only metadata/localization are stubbed; file creation and image caching are production code.
struct Attachment: Hashable {
    var id: String
    var name: String
    var mime: String
    var size: Int
    var width: Int?
    var height: Int?
}
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: key, arguments: arguments)
}

@main
struct AttachmentFilesTests {
    static func png(width: Int, height: Int, color: NSColor) -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])!
    }

    @MainActor
    static func main() throws {
        let red = png(width: 800, height: 400, color: .red)
        let blue = png(width: 640, height: 480, color: .blue)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        if CommandLine.arguments.contains("paste") {
            // More than two writes also catches an unlucky boundary between timestamp seconds.
            var pasted: [OutgoingAttachment] = []
            defer {
                for file in pasted {
                    try? FileManager.default.removeItem(at: file.url)
                    // New production code stores each paste in its own directory.
                    if file.url.deletingLastPathComponent().lastPathComponent != "lorca-paste" {
                        try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent())
                    }
                }
            }
            for index in 0..<6 {
                pasted.append(try OutgoingAttachment.make(pastedPNG: index.isMultiple(of: 2) ? red : blue))
            }
            precondition(Set(pasted.map(\.url)).count == pasted.count,
                "Rapid pasted images must have independent files")
            precondition(Set(pasted.map { $0.attachment.id }).count == pasted.count)
            for (index, file) in pasted.enumerated() {
                let bytes = try Data(contentsOf: file.url)
                precondition(bytes == (index.isMultiple(of: 2) ? red : blue), "Each attachment must preserve its own bytes")
            }
            print("PASS: Rapid pasted images keep distinct paths, IDs and original bytes")
            return
        }

        let imageURL = temporary.appendingPathComponent("attachment.png")
        try red.write(to: imageURL)
        let chip = Thumbnails.image(at: imageURL, maxPixels: 112)!
        let bubble = Thumbnails.image(at: imageURL, maxPixels: 600)!
        precondition(chip.size.width == 112)
        precondition(bubble.size.width == 600, "A bubble must not reuse the small composer thumbnail")
        precondition(Thumbnails.image(at: imageURL, maxPixels: 600) === bubble, "An unchanged image should reuse its cache")
        print("PASS: Composer and transcript thumbnails retain their requested resolution")

        try blue.write(to: imageURL)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1234)], ofItemAtPath: imageURL.path)
        let replaced = Thumbnails.image(at: imageURL, maxPixels: 600)!
        precondition(replaced !== bubble && replaced.size.height == 450,
            "Replacing an attachment must not display stale cached content")
        try FileManager.default.removeItem(at: imageURL)
        precondition(Thumbnails.image(at: imageURL, maxPixels: 600) == nil,
            "A deleted attachment must not keep showing a misleading cached preview")
        print("PASS: Replaced or removed local files invalidate their thumbnails")
    }
}
