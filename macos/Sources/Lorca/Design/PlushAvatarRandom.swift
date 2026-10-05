import Foundation

extension PlushAvatar {
    /// Each full cycle contains every shape once. A partial cycle has no repeated shape.
    static func randomShapeIDs(count: Int) -> [String] {
        var generator = SystemRandomNumberGenerator()
        return randomShapeIDs(count: count, using: &generator)
    }

    static func randomShapeIDs<R: RandomNumberGenerator>(count: Int, using generator: inout R) -> [String] {
        shuffledCycles(shapeOptions.map(\.id), count: count, using: &generator)
    }

    /// Store these values in the picker so its thumbnails and saved selection share one look.
    /// Shapes and body colors each use shuffled cycles, giving eight candidates eight of each.
    static func randomConfigurations(count: Int) -> [Configuration] {
        var generator = SystemRandomNumberGenerator()
        return randomConfigurations(count: count, using: &generator)
    }

    static func randomConfigurations<R: RandomNumberGenerator>(count: Int, using generator: inout R) -> [Configuration] {
        guard count > 0 else { return [] }
        let shapes = randomShapeIDs(count: count, using: &generator)
        let colors = shuffledCycles(palette.map(\.hex), count: count, using: &generator)
        return zip(shapes, colors).map { shape, color in
            randomParts(shape: shape, color: color, using: &generator)
        }
    }

    /// A new roll changes both the current shape and the current palette color.
    static func randomConfiguration(excludingShape: String? = nil, excludingColor: String? = nil) -> Configuration {
        var generator = SystemRandomNumberGenerator()
        return randomConfiguration(excludingShape: excludingShape, excludingColor: excludingColor, using: &generator)
    }

    static func randomConfiguration<R: RandomNumberGenerator>(
        excludingShape: String? = nil, excludingColor: String? = nil, using generator: inout R
    ) -> Configuration {
        let colorToExclude = excludingColor.flatMap(normalizedHex)
        let shape = shapeOptions.map(\.id).filter { $0 != excludingShape }.randomElement(using: &generator) ?? "circle"
        let color = palette.map(\.hex).filter { $0 != colorToExclude }.randomElement(using: &generator) ?? "#f667ad"
        return randomParts(shape: shape, color: color, using: &generator)
    }

    private static func randomParts<R: RandomNumberGenerator>(
        shape: String, color: String, using generator: inout R
    ) -> Configuration {
        let eyes = eyeOptions.randomElement(using: &generator)?.id ?? "sparkle"
        let glasses = glassesOptions.randomElement(using: &generator)?.id ?? "none"
        let accessory = accessoryOptions.randomElement(using: &generator)?.id ?? "none"
        return Configuration(
            shape: shape, color: color, eyes: eyes, glasses: glasses, accessory: accessory,
            glassesColor: "#222222", accessoryColor: accessory == "crown" ? "#ffd03e" : "#222222"
        )
    }

    private static func shuffledCycles<R: RandomNumberGenerator>(
        _ pool: [String], count: Int, using generator: inout R
    ) -> [String] {
        guard count > 0, !pool.isEmpty else { return [] }
        var result: [String] = []
        result.reserveCapacity(count)
        while result.count < count {
            var cycle = pool.shuffled(using: &generator)
            if cycle.count > 1, cycle.first == result.last {
                cycle.swapAt(0, Int.random(in: 1..<cycle.count, using: &generator))
            }
            result.append(contentsOf: cycle.prefix(count - result.count))
        }
        return result
    }
}
