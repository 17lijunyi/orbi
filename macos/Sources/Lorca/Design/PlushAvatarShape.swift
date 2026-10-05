import CoreGraphics

/// Shared outlines for the native shape picker and the reproducible plush artwork renderer.
/// Coordinates are centred on the body, with y increasing toward the bottom of the artwork.
enum PlushAvatarShape {
    static let identifiers = ["circle", "triangle", "capsule", "bear", "blob", "heart", "butterfly", "sprout", "flower", "pebble", "diamond"]

    static func path(_ kind: String) -> CGPath {
        let p = CGMutablePath()
        func move(_ x: CGFloat, _ y: CGFloat) { p.move(to: CGPoint(x: x, y: y)) }
        func curve(_ x: CGFloat, _ y: CGFloat, _ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) {
            p.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: a, y: b), control2: CGPoint(x: c, y: d))
        }
        switch kind {
        case "triangle":
            move(-67, -258)
            curve(67, -258, -34, -320, 34, -320)
            curve(287, 179, 103, -199, 268, 142)
            curve(220, 278, 324, 252, 287, 278)
            p.addLine(to: CGPoint(x: -220, y: 278))
            curve(-287, 179, -287, 278, -324, 252)
            curve(-67, -258, -268, 142, -103, -199)
        case "capsule":
            p.addRoundedRect(in: CGRect(x: -314, y: -209, width: 628, height: 418), cornerWidth: 209, cornerHeight: 209)
        case "bear":
            p.addRoundedRect(in: CGRect(x: -294, y: -226, width: 588, height: 508), cornerWidth: 236, cornerHeight: 236)
            p.addEllipse(in: CGRect(x: -257, y: -321, width: 171, height: 177))
            p.addEllipse(in: CGRect(x: 86, y: -321, width: 171, height: 177))
        case "blob":
            radial(p, lobes: 5, radius: 280, amplitude: 42, phase: -0.9, asymmetry: true)
        case "heart":
            move(0, -181)
            curve(-249, -236, -58, -318, -185, -339)
            curve(-235, 50, -330, -163, -309, -72)
            curve(-54, 285, -164, 177, -96, 276)
            curve(54, 285, -21, 322, 21, 322)
            curve(235, 50, 96, 276, 164, 177)
            curve(249, -236, 309, -72, 330, -163)
            curve(0, -181, 185, -339, 58, -318)
        case "butterfly":
            move(0, -178)
            curve(-251, -236, -135, -298, -204, -308)
            curve(-221, -11, -339, -158, -273, -52)
            curve(-258, 234, -333, 90, -308, 189)
            curve(0, 212, -185, 296, -91, 259)
            curve(258, 234, 91, 259, 185, 296)
            curve(221, -11, 308, 189, 333, 90)
            curve(251, -236, 273, -52, 339, -158)
            curve(0, -178, 204, -308, 135, -298)
        case "sprout":
            move(-76, -189)
            curve(-57, -316, -86, -280, -92, -340)
            curve(47, -283, -27, -333, 10, -305)
            curve(147, -298, 105, -361, 184, -325)
            curve(113, -169, 201, -267, 169, -210)
            curve(267, 72, 217, -142, 281, -57)
            curve(0, 317, 260, 223, 166, 317)
            curve(-267, 72, -166, 317, -260, 223)
            curve(-76, -189, -282, -51, -200, -160)
        case "flower":
            radial(p, lobes: 12, radius: 289, amplitude: 18, phase: -0.2, asymmetry: false)
        case "pebble":
            move(-129, -270)
            curve(95, -302, -18, -286, 43, -353)
            curve(270, -127, 135, -268, 259, -174)
            curve(231, 165, 312, -57, 254, 54)
            curve(72, 280, 201, 242, 148, 244)
            curve(-123, 276, -7, 322, -72, 331)
            curve(-273, 111, -175, 238, -295, 172)
            curve(-258, -97, -296, 51, -274, -25)
            curve(-129, -270, -238, -201, -223, -249)
        case "diamond":
            move(-47, -290)
            curve(47, -290, -21, -319, 21, -319)
            p.addLine(to: CGPoint(x: 284, y: -48))
            curve(284, 48, 314, -17, 314, 17)
            p.addLine(to: CGPoint(x: 47, y: 290))
            curve(-47, 290, 21, 319, -21, 319)
            p.addLine(to: CGPoint(x: -284, y: 48))
            curve(-284, -48, -314, 17, -314, -17)
        default:
            p.addEllipse(in: CGRect(x: -300, y: -307, width: 600, height: 614))
        }
        p.closeSubpath()
        return p
    }

    private static func radial(_ path: CGMutablePath, lobes: Int, radius: Double, amplitude: Double, phase: Double, asymmetry: Bool) {
        for i in 0..<360 {
            let angle = Double(i) / 360 * .pi * 2
            let variation = asymmetry ? 9 * sin(angle * 2 + 0.4) : 0
            let r = radius + amplitude * cos(angle * Double(lobes) + phase) + variation
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
    }

    /// Accessories attach to the changed body's crown and hem while the face stays central.
    static func accessoryOffset(shape: String, accessory: String) -> CGFloat {
        if accessory == "bowtie" {
            switch shape {
            case "capsule": return -89
            case "butterfly": return -54
            case "triangle": return -18
            default: return 0
            }
        }
        if ["bowler", "tophat", "beret", "pompom", "tuft", "crown"].contains(accessory) {
            switch shape {
            case "capsule": return 98
            case "bear": return 70
            case "heart", "butterfly": return 72
            case "sprout": return -6
            default: return 0
            }
        }
        return 0
    }

    static func accessoryWidthScale(shape: String, accessory: String) -> CGFloat {
        guard accessory == "headphones" else { return 1 }
        switch shape {
        case "triangle": return 0.67
        case "diamond": return 0.91
        case "sprout": return 0.92
        default: return 1
        }
    }
}
