import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Run from the repository root:
/// swiftc -O macos/Sources/Lorca/Design/PlushAvatarShape.swift scripts/artwork/generate-plush-shapes.swift -o /tmp/orbi-plush-shapes
/// /tmp/orbi-plush-shapes
@main
enum GeneratePlushShapes {
    static let side = 900
    static let center = CGPoint(x: 441, y: 458)

    static func bitmap() -> CGContext {
        CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    }

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resource = root.appendingPathComponent("macos/Resources/PlushAvatars")
        let source = CGImageSourceCreateWithURL(resource.appendingPathComponent("base.png") as CFURL, nil)!
        let original = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let sourceContext = bitmap()
        sourceContext.draw(original, in: CGRect(x: 0, y: 0, width: side, height: side))
        let pixels = Array(UnsafeBufferPointer(start: sourceContext.data!.assumingMemoryBound(to: UInt8.self), count: side * side * 4))
        let orbit = orbitLayers(pixels: pixels)
        let destination = resource.appendingPathComponent("shapes", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for shape in PlushAvatarShape.identifiers where shape != "circle" {
            let start = Date()
            let image = render(shape: shape, pixels: pixels, orbit: orbit)
            let url = destination.appendingPathComponent(shape + ".png")
            let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(output, image, nil)
            guard CGImageDestinationFinalize(output) else { fatalError("PNG encoding failed: \(shape)") }
            print("\(shape): \(String(format: "%0.2f", Date().timeIntervalSince(start)))s")
        }
    }

    struct Orbit { let back: [UInt8]; let front: [UInt8] }

    /// The source planet hides parts of its orbit. Rebuilding the complete soft tube makes
    /// those newly exposed parts continuous when a smaller or indented body is selected.
    static func orbitLayers(pixels: [UInt8]) -> Orbit {
        var back = [UInt8](repeating: 0, count: side * side * 4)
        var front = back
        let rotation = -32.0 * Double.pi / 180
        let cosine = cos(rotation), sine = sin(rotation)
        let rx = 442.0, ry = 180.0
        for y in 0..<side {
            for x in 0..<side {
                let offset = (y * side + x) * 4
                let dx = Double(x) - 453, dy = Double(y) - 435
                let u = dx * cosine + dy * sine, v = -dx * sine + dy * cosine
                var angle = atan2(v * rx, u * ry)
                for _ in 0..<4 {
                    let a = cos(angle), b = sin(angle)
                    let ex = rx * a - u, ey = ry * b - v
                    let first = ex * (-rx * b) + ey * (ry * a)
                    let second = rx * rx * b * b + ry * ry * a * a - ex * rx * a - ey * ry * b
                    if abs(second) > 1 { angle -= max(-0.3, min(0.3, first / second)) }
                }
                let px = rx * cos(angle), py = ry * sin(angle)
                let distance = hypot(u - px, v - py)
                let random = Double(hash(x, y) & 1023) / 1023
                let width = 34.0
                let coverage = max(0, min(1, width + (random - 0.5) * 4 - distance + 0.5))
                guard coverage > 0 else { continue }
                let depth = sqrt(max(0, 1 - pow(distance / width, 2)))
                let shade = 0.68 + 0.29 * depth + 0.025 * sin(angle)
                let sx = 340 + mirrored(Int(Double(x) * 0.91 + Double(y) * 0.19), length: 200)
                let sy = 250 + mirrored(Int(Double(y) * 0.83 - Double(x) * 0.13), length: 185)
                let sample = (sy * side + sx) * 4
                let luminance = (Double(pixels[sample]) + Double(pixels[sample + 1]) + Double(pixels[sample + 2])) / 3
                var average = 0.0
                for oy in [-9, -3, 3, 9] {
                    for ox in [-9, -3, 3, 9] {
                        let nearby = ((sy + oy) * side + sx + ox) * 4
                        average += (Double(pixels[nearby]) + Double(pixels[nearby + 1]) + Double(pixels[nearby + 2])) / 3
                    }
                }
                let texture = max(0.81, min(1.15, luminance / max(1, average / 16)))
                let isFront = sin(angle) >= 0
                for channel in 0..<3 {
                    let value = UInt8(max(0, min(255, [247.0, 237.0, 222.0][channel] * shade * texture * coverage)))
                    if isFront { front[offset + channel] = value } else { back[offset + channel] = value }
                }
                if isFront { front[offset + 3] = UInt8(coverage * 255) }
                else { back[offset + 3] = UInt8(coverage * 255) }
            }
        }
        // Keep the satellite's original fur, highlights, position and scale.
        for y in 218..<367 {
            for x in 738..<890 {
                let distance = hypot((Double(x) - 815) / 67, (Double(y) - 290) / 64)
                let coverage = max(0, min(1, (1 - distance) * 30))
                guard coverage > 0 else { continue }
                let offset = (y * side + x) * 4
                let alpha = Double(pixels[offset + 3]) / 255 * coverage
                for channel in 0..<3 {
                    front[offset + channel] = UInt8(min(255, Double(pixels[offset + channel]) * coverage + Double(front[offset + channel]) * (1 - alpha)))
                }
                front[offset + 3] = UInt8(min(255, alpha * 255 + Double(front[offset + 3]) * (1 - alpha)))
            }
        }
        return Orbit(back: back, front: front)
    }

    static func render(shape: String, pixels: [UInt8], orbit: Orbit) -> CGImage {
        let c = bitmap()
        let out = c.data!.assumingMemoryBound(to: UInt8.self)
        let outline = PlushAvatarShape.path(shape)
        let count = 4096
        let radii: [Double] = (0..<count).map { i in
            let angle = Double(i) / Double(count) * .pi * 2
            let dx = cos(angle), dy = sin(angle)
            var low = 0.0, high = 390.0
            for _ in 0..<13 {
                let middle = (low + high) * 0.5
                if outline.contains(CGPoint(x: dx * middle, y: dy * middle)) { low = middle } else { high = middle }
            }
            return (low + high) * 0.5
        }
        for y in 0..<side {
            for x in 0..<side {
                let pixel = y * side + x, offset = pixel * 4
                let dx = Double(x) - center.x, dy = Double(y) - center.y
                let distance = hypot(dx, dy)
                for channel in 0..<4 { out[offset + channel] = orbit.back[offset + channel] }
                let angle = atan2(dy, dx)
                let index = Int((angle < 0 ? angle + .pi * 2 : angle) / (.pi * 2) * Double(count)) % count
                let radius = radii[index]
                let noise = Double(hash(x, y) & 1023) / 1023
                let edge = radius + (noise - 0.47) * 5
                let coverage = max(0, min(1, edge - distance + 0.6))
                if coverage > 0 {
                    let t = min(0.997, distance / max(1, radius))
                    let unitX = distance > 0 ? dx / distance : 0
                    let unitY = distance > 0 ? dy / distance : 0
                    var sx = center.x + unitX * t * 240
                    var sy = 405 - abs(unitY * t * 232)
                    sx = min(898, max(1, sx)); sy = min(898, max(1, sy))
                    let sample = (Int(sy) * side + Int(sx)) * 4
                    let alpha = max(1, Double(pixels[sample + 3])) / 255
                    let edgeShade = 1 - 0.20 * pow(t, 4)
                    let directional = 1 - 0.10 * unitY * pow(t, 2) - 0.035 * unitX * pow(t, 2)
                    let newAlpha = coverage
                    let remaining = 1 - newAlpha
                    for channel in 0..<3 {
                        let straight = Double(pixels[sample + channel]) / alpha
                        let value = min(255, straight * edgeShade * directional)
                        out[offset + channel] = UInt8(min(255, max(0, value * newAlpha + Double(out[offset + channel]) * remaining)))
                    }
                    out[offset + 3] = UInt8(min(255, newAlpha * 255 + Double(out[offset + 3]) * remaining))
                }
                let nearAlpha = Double(orbit.front[offset + 3]) / 255
                if nearAlpha > 0 {
                    for channel in 0..<3 {
                        out[offset + channel] = UInt8(min(255, Double(orbit.front[offset + channel]) + Double(out[offset + channel]) * (1 - nearAlpha)))
                    }
                    out[offset + 3] = UInt8(min(255, nearAlpha * 255 + Double(out[offset + 3]) * (1 - nearAlpha)))
                }
            }
        }
        return c.makeImage()!
    }

    static func hash(_ x: Int, _ y: Int) -> UInt32 {
        var n = UInt32(x) &* 374_761_393 &+ UInt32(y) &* 668_265_263
        n = (n ^ (n >> 13)) &* 1_274_126_177
        return n ^ (n >> 16)
    }

    static func mirrored(_ value: Int, length: Int) -> Int {
        let period = length * 2
        let wrapped = (value % period + period) % period
        return wrapped < length ? wrapped : period - wrapped - 1
    }
}
