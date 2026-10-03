import AppKit

/// Window colors are a local visual preference, separate from the account and app icon.
enum WindowBackground: String, CaseIterable {
    case nebula, bay, moss, tea, berry, white, black

    var title: String {
        switch self {
        case .nebula: "星雾"
        case .bay: "深湾"
        case .moss: "青苔"
        case .tea: "岩茶"
        case .berry: "暮莓"
        case .white: "纯白"
        case .black: "纯黑"
        }
    }

    /// Three stops at 0%, 52%, and 100%; solid backgrounds repeat one color.
    var colors: [NSColor] {
        let values: [UInt32]
        switch self {
        case .nebula: values = [0x343d60, 0x535b80, 0x665579]
        case .bay: values = [0x243e56, 0x345b70, 0x426d78]
        case .moss: values = [0x294943, 0x45665c, 0x5a7066]
        case .tea: values = [0x49413d, 0x63554c, 0x78675c]
        case .berry: values = [0x453c59, 0x624b6b, 0x77546a]
        case .white: values = [0xffffff, 0xffffff, 0xffffff]
        case .black: values = [0x000000, 0x000000, 0x000000]
        }
        return values.map { value in
            NSColor(
                srgbRed: CGFloat((value >> 16) & 0xff) / 255,
                green: CGFloat((value >> 8) & 0xff) / 255,
                blue: CGFloat(value & 0xff) / 255, alpha: 1
            )
        }
    }

    var isLight: Bool { self == .white }

    static let didChange = Notification.Name("orbi.windowBackground.didChange")
    private static let preferenceKey = "orbi.windowBackground"

    /// UserDefaults follows the current bundle, keeping development and release independent.
    static var current: WindowBackground {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .nebula
    }

    @MainActor
    static func choose(_ background: WindowBackground) {
        UserDefaults.standard.set(background.rawValue, forKey: preferenceKey)
        apply()
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    @MainActor
    static func apply() {
        NSApp.appearance = NSAppearance(named: current.isLight ? .aqua : .darkAqua)
    }
}
