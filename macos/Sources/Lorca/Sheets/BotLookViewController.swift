import AppKit
import UniformTypeIdentifiers

/// The native character editor. Draft changes stay in the sheet until Save applies
/// the appearance to a bot avatar or to the application's icon.
final class BotLookViewController: NSViewController, NSTextFieldDelegate {
    /// Protocol-compatible legacy symbols, also used by clients that do not render plush avatars.
    static let symbols: [String] = [
        "sparkles", "wand.and.stars", "hammer.fill", "book.fill",
        "paintbrush.fill", "chart.bar.fill", "terminal.fill", "globe",
        "brain.head.profile", "magnifyingglass", "envelope.fill", "calendar",
        "flask.fill", "bolt.fill", "leaf.fill", "shield.fill",
        "binoculars.fill", "chevron.left.forwardslash.chevron.right", "pencil.and.scribble", "bolt.horizontal.fill",
        "flame.fill",
    ]
    static let imageSide: CGFloat = 512

    private struct Look {
        let id: String
        let title: String
        let configuration: PlushAvatar.Configuration
    }

    /// Every preset preserves Orbi's planet, diagonal ring and satellite.
    private static let looks: [Look] = [
        Look(id: "starry-pink", title: "星光粉", configuration: .init()),
        Look(id: "pink-gentleman", title: "粉色绅士", configuration: .init(eyes: "sleepy", glasses: "monocle", accessory: "bowtie")),
        Look(id: "blue-artist", title: "蓝色画家", configuration: .init(color: "#4671fa", eyes: "oval", accessory: "beret")),
        Look(id: "yellow-scholar", title: "柠檬学者", configuration: .init(color: "#ffd03e", eyes: "sleepy", glasses: "round", accessory: "bowtie")),
        Look(id: "violet-cool", title: "紫色墨镜", configuration: .init(color: "#9d53f7", eyes: "tall", glasses: "shades")),
        Look(id: "lime-curious", title: "青柠好奇心", configuration: .init(color: "#b4d500", eyes: "googly", accessory: "bowtie")),
        Look(id: "coral-magician", title: "珊瑚魔术师", configuration: .init(color: "#ff7a63", eyes: "round", glasses: "monocle", accessory: "tophat")),
        Look(id: "sky-listener", title: "天空音乐家", configuration: .init(color: "#05adeb", eyes: "dots", glasses: "classic", accessory: "headphones")),
        Look(id: "mint-prince", title: "薄荷小王子", configuration: .init(color: "#05b89f", eyes: "sparkle", glasses: "round", accessory: "crown", accessoryColor: "#ffd03e")),
        Look(id: "orchid-dream", title: "兰紫绒球", configuration: .init(color: "#d862da", eyes: "lashes", accessory: "pompom", accessoryColor: "#f667ad")),
        Look(id: "cream-sprout", title: "奶油小呆毛", configuration: .init(color: "#e9dccc", eyes: "tall", accessory: "tuft", accessoryColor: "#914d2d")),
        Look(id: "lavender-stroll", title: "薰衣草漫步", configuration: .init(color: "#ab94e8", eyes: "oval", glasses: "square", accessory: "bowler")),
    ]

    private enum Tab: Int, CaseIterable {
        case shape, eyes, glasses, accessory
        var title: String {
            switch self {
            case .shape: "形象"
            case .eyes: "眼睛"
            case .glasses: "眼镜"
            case .accessory: "配饰"
            }
        }
        var key: String {
            switch self {
            case .shape: "shape"
            case .eyes: "eyes"
            case .glasses: "glasses"
            case .accessory: "accessory"
            }
        }
        var category: PlushAvatar.Category? {
            switch self {
            case .shape: nil
            case .eyes: .eyes
            case .glasses: .glasses
            case .accessory: .accessory
            }
        }
    }

    private let store = AppStore.shared
    private let botID: Bot.ID?
    private let editorTitle: String
    private let onSave: ((PlushAvatar.Configuration, URL?) throws -> Void)?
    private var draft: PlushAvatar.Configuration
    private var selectedTab: Tab = .shape
    private var importedImage: (url: URL, image: NSImage)?
    private var keepsExistingImage = false
    private var existingImage: NSImage?
    private let preview = NSImageView()
    private let options = NSStackView()
    private let palette = NSView()
    private let colorRow = NSStackView()
    private let saveButton = PlushEditorButton()
    private var tabs: [PlushEditorButton] = []
    private var optionButtons: [(id: String, button: PlushEditorButton)] = []
    private var swatches: [(hex: String, button: PlushEditorButton)] = []
    private var customColorPanel: NSView?
    private var customColorField: NSTextField?
    private var customColorHint: NSTextField?

    init(botID: Bot.ID) {
        self.botID = botID
        editorTitle = AppStore.shared.bot(botID)?.name ?? "Orbi"
        onSave = nil
        if let bot = AppStore.shared.bot(botID) {
            draft = PlushAvatar.configuration(for: bot)
            if let avatar = bot.avatar, PlushAvatar.Configuration(fileName: avatar.name) == nil {
                existingImage = AppStore.shared.avatarImage(for: bot)
                keepsExistingImage = true
            }
        } else {
            draft = PlushAvatar.Configuration()
        }
        super.init(nibName: nil, bundle: nil)
    }

    /// The optional URL represents an imported image; a nil URL requests the composed
    /// plush configuration. The caller persists its own app-icon or avatar setting.
    init(title: String, configuration: PlushAvatar.Configuration, importedImageURL: URL? = nil,
         onSave: @escaping (PlushAvatar.Configuration, URL?) throws -> Void) {
        botID = nil
        editorTitle = title
        draft = configuration.normalized
        self.onSave = onSave
        if let importedImageURL, let image = NSImage(contentsOf: importedImageURL), image.isValid {
            importedImage = (importedImageURL, image)
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 780, height: 500))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        container.appearance = NSAppearance(named: .aqua)
        container.setAccessibilityLabel(botID == nil ? "定制应用图标" : "定制智能体形象")
        let left = NSView(), right = NSView()
        for pane in [left, right] {
            pane.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(pane)
        }
        right.wantsLayer = true
        right.layer?.backgroundColor = NSColor(white: 0.968, alpha: 1).cgColor
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 780),
            container.heightAnchor.constraint(equalToConstant: 500),
            left.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            left.topAnchor.constraint(equalTo: container.topAnchor),
            left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            left.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.608),
            right.leadingAnchor.constraint(equalTo: left.trailingAnchor),
            right.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            right.topAnchor.constraint(equalTo: container.topAnchor),
            right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        buildControls(in: left)
        buildPreview(in: right)
        view = container
        preferredContentSize = NSSize(width: 780, height: 500)
        rebuildOptions()
        rebuildPalette()
        refresh()
    }

    private func buildControls(in pane: NSView) {
        let back = iconButton("arrow.left", title: "取消并返回", identifier: "back") { [weak self] in self?.cancelOperation(nil) }
        back.keyEquivalent = "\u{1b}"
        pane.addSubview(back)
        let navigation = NSStackView()
        navigation.translatesAutoresizingMaskIntoConstraints = false
        navigation.orientation = .horizontal
        navigation.spacing = 19
        navigation.alignment = .centerY
        for tab in Tab.allCases {
            let button = PlushEditorButton()
            button.title = tab.title
            button.textSize = 15
            button.identifier = NSUserInterfaceItemIdentifier("orbi.look.tab.\(tab.key)")
            button.setAccessibilityLabel(tab.title)
            button.onPress = { [weak self] in
                guard let self else { return }
                closeCustomColor()
                selectedTab = tab
                rebuildOptions()
                rebuildPalette()
                refresh()
            }
            button.widthAnchor.constraint(equalToConstant: 35).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            navigation.addArrangedSubview(button)
            tabs.append(button)
        }
        pane.addSubview(navigation)
        let random = PlushEditorButton()
        random.title = "随机搭配"
        random.textSize = 12
        random.toolTip = "随机生成新的颜色、眼睛、眼镜和配饰组合"
        random.setAccessibilityLabel("随机搭配")
        random.identifier = NSUserInterfaceItemIdentifier("orbi.look.randomize")
        random.onPress = { [weak self] in self?.randomize() }
        NSLayoutConstraint.activate([
            random.widthAnchor.constraint(equalToConstant: 64),
            random.heightAnchor.constraint(equalToConstant: 30),
        ])
        let upload = iconButton("photo.badge.plus", title: "上传自己的图片", identifier: "upload") { [weak self] in self?.chooseImage() }
        pane.addSubview(random)
        pane.addSubview(upload)

        options.orientation = .vertical
        options.alignment = .leading
        options.spacing = 11
        options.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(options)

        palette.translatesAutoresizingMaskIntoConstraints = false
        palette.wantsLayer = true
        palette.layer?.backgroundColor = NSColor.white.cgColor
        palette.layer?.borderColor = NSColor(white: 0.925, alpha: 1).cgColor
        palette.layer?.borderWidth = 1.2
        palette.layer?.cornerRadius = 28
        pane.addSubview(palette)
        colorRow.translatesAutoresizingMaskIntoConstraints = false
        colorRow.orientation = .horizontal
        colorRow.distribution = .equalSpacing
        colorRow.alignment = .centerY
        palette.addSubview(colorRow)
        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 16),
            back.topAnchor.constraint(equalTo: pane.topAnchor, constant: 15),
            navigation.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 16),
            navigation.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            upload.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -15),
            upload.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            random.trailingAnchor.constraint(equalTo: upload.leadingAnchor, constant: -12),
            random.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            options.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 14),
            options.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -14),
            options.topAnchor.constraint(equalTo: pane.topAnchor, constant: 66),
            options.bottomAnchor.constraint(lessThanOrEqualTo: palette.topAnchor, constant: -15),
            palette.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 14),
            palette.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -14),
            palette.bottomAnchor.constraint(equalTo: pane.bottomAnchor, constant: -18),
            palette.heightAnchor.constraint(equalToConstant: 56),
            colorRow.leadingAnchor.constraint(equalTo: palette.leadingAnchor, constant: 11),
            colorRow.trailingAnchor.constraint(equalTo: palette.trailingAnchor, constant: -11),
            colorRow.centerYAnchor.constraint(equalTo: palette.centerYAnchor),
        ])
    }

    private func buildPreview(in pane: NSView) {
        let close = iconButton("xmark", title: "取消并关闭", identifier: "close") { [weak self] in self?.dismiss(nil) }
        pane.addSubview(close)
        let name = NSTextField(labelWithString: editorTitle)
        name.translatesAutoresizingMaskIntoConstraints = false
        name.font = .systemFont(ofSize: 46, weight: .bold)
        name.textColor = PlushEditorButton.ink
        name.alignment = .center
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pane.addSubview(name)
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.identifier = NSUserInterfaceItemIdentifier("orbi.look.preview")
        preview.setAccessibilityLabel(botID == nil ? "毛绒星球应用图标预览" : "毛绒星球头像预览")
        pane.addSubview(preview)
        saveButton.title = "保存"
        saveButton.textSize = 17
        saveButton.style = .pill
        saveButton.keyEquivalent = "\r"
        saveButton.identifier = NSUserInterfaceItemIdentifier("orbi.look.save")
        saveButton.setAccessibilityLabel(botID == nil ? "保存应用图标" : "保存头像")
        saveButton.onPress = { [weak self] in self?.save() }
        pane.addSubview(saveButton)
        NSLayoutConstraint.activate([
            close.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -15),
            close.topAnchor.constraint(equalTo: pane.topAnchor, constant: 15),
            name.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 20),
            name.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -20),
            name.topAnchor.constraint(equalTo: pane.topAnchor, constant: 59),
            preview.widthAnchor.constraint(equalToConstant: 280),
            preview.heightAnchor.constraint(equalTo: preview.widthAnchor),
            preview.centerXAnchor.constraint(equalTo: pane.centerXAnchor),
            preview.centerYAnchor.constraint(equalTo: pane.centerYAnchor, constant: 12),
            saveButton.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 23),
            saveButton.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -23),
            saveButton.bottomAnchor.constraint(equalTo: pane.bottomAnchor, constant: -28),
            saveButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func iconButton(_ symbol: String, title: String, identifier: String, action: @escaping () -> Void) -> PlushEditorButton {
        let button = PlushEditorButton()
        button.icon = Glyph.symbol(symbol, pointSize: 17, weight: .regular, color: NSColor(white: 0.49, alpha: 1))
        button.toolTip = title
        button.setAccessibilityLabel(title)
        button.identifier = NSUserInterfaceItemIdentifier("orbi.look.\(identifier)")
        button.onPress = action
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 26),
            button.heightAnchor.constraint(equalToConstant: 30),
        ])
        return button
    }

    private func rebuildOptions() {
        for row in options.arrangedSubviews { options.removeArrangedSubview(row); row.removeFromSuperview() }
        optionButtons.removeAll()
        let choices: [(id: String, title: String)]
        switch selectedTab {
        case .shape: choices = Self.looks.map { ($0.id, $0.title) }
        case .eyes: choices = PlushAvatar.eyeOptions.map { ($0.id, $0.title) }
        case .glasses: choices = PlushAvatar.glassesOptions.map { ($0.id, $0.title) }
        case .accessory: choices = PlushAvatar.accessoryOptions.map { ($0.id, $0.title) }
        }
        for start in stride(from: 0, to: choices.count, by: 4) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.spacing = 11
            row.translatesAutoresizingMaskIntoConstraints = false
            options.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: options.widthAnchor).isActive = true
            for offset in 0..<4 {
                let index = start + offset
                if index < choices.count {
                    let choice = choices[index]
                    let button = PlushEditorButton()
                    button.style = .tile
                    button.toolTip = choice.title
                    button.setAccessibilityLabel(choice.title)
                    button.identifier = NSUserInterfaceItemIdentifier("orbi.look.option.\(choice.id)")
                    button.onPress = { [weak self] in self?.selectOption(choice.id) }
                    button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
                    row.addArrangedSubview(button)
                    optionButtons.append((choice.id, button))
                } else {
                    let spacer = NSView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(spacer)
                }
            }
        }
        refreshOptionImages()
    }

    private func refreshOptionImages() {
        for item in optionButtons {
            if let category = selectedTab.category {
                let color = selectedTab == .glasses ? draft.glassesColor : selectedTab == .accessory ? draft.accessoryColor : "#202124"
                item.button.artwork = PlushAvatar.thumbnail(category: category, kind: item.id, color: color, side: 220)
            } else if let look = Self.looks.first(where: { $0.id == item.id }) {
                item.button.artwork = PlushAvatar.image(for: look.configuration, side: 260)
            }
        }
    }

    private func rebuildPalette() {
        for button in colorRow.arrangedSubviews { colorRow.removeArrangedSubview(button); button.removeFromSuperview() }
        swatches.removeAll()
        palette.isHidden = selectedTab == .eyes
        guard selectedTab != .eyes else { return }
        let colors = selectedTab == .shape ? PlushAvatar.palette : PlushAvatar.componentPalette
        for color in colors {
            let button = PlushEditorButton()
            button.style = .swatch
            button.swatchColor = Self.color(hex: color.hex)
            button.toolTip = color.title
            button.identifier = NSUserInterfaceItemIdentifier("orbi.look.color.\(color.hex.lowercased())")
            button.setAccessibilityLabel(color.title)
            button.onPress = { [weak self] in self?.selectColor(color.hex) }
            let side: CGFloat = colors.count > 9 ? 29 : 35
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: side),
                button.heightAnchor.constraint(equalTo: button.widthAnchor),
            ])
            colorRow.addArrangedSubview(button)
            swatches.append((color.hex, button))
        }
        let custom = PlushEditorButton()
        custom.title = "DIY"
        custom.textSize = 13
        custom.toolTip = "输入 HEX 色值，自定义\(colorTargetName)颜色"
        custom.setAccessibilityLabel("DIY \(colorTargetName)颜色")
        custom.identifier = NSUserInterfaceItemIdentifier("orbi.look.custom-color")
        custom.onPress = { [weak self] in self?.chooseCustomColor() }
        NSLayoutConstraint.activate([
            custom.widthAnchor.constraint(equalToConstant: 48),
            custom.heightAnchor.constraint(equalToConstant: 35),
        ])
        colorRow.addArrangedSubview(custom)
    }

    private var selectedOption: String {
        switch selectedTab {
        case .shape: Self.looks.first(where: { $0.configuration.normalized == draft.normalized })?.id ?? ""
        case .eyes: draft.eyes
        case .glasses: draft.glasses
        case .accessory: draft.accessory
        }
    }

    private var selectedColor: String {
        switch selectedTab {
        case .shape, .eyes: draft.color
        case .glasses: draft.glassesColor
        case .accessory: draft.accessoryColor
        }
    }

    private func usePlushDraft() {
        closeCustomColor()
        importedImage = nil
        keepsExistingImage = false
    }

    private func selectOption(_ id: String) {
        usePlushDraft()
        switch selectedTab {
        case .shape:
            guard let look = Self.looks.first(where: { $0.id == id }) else { return }
            draft = look.configuration
        case .eyes: draft.eyes = id
        case .glasses: draft.glasses = id
        case .accessory: draft.accessory = id
        }
        refresh()
    }

    private func selectColor(_ hex: String) {
        usePlushDraft()
        switch selectedTab {
        case .shape, .eyes: draft.color = hex
        case .glasses: draft.glassesColor = hex
        case .accessory: draft.accessoryColor = hex
        }
        refreshOptionImages()
        refresh()
    }

    private func randomize() {
        usePlushDraft()
        // A new color guarantees a visibly different result even if all parts repeat.
        let otherColors = PlushAvatar.palette.filter { $0.hex.lowercased() != draft.color.lowercased() }
        draft.color = otherColors.randomElement()?.hex ?? "#f667ad"
        draft.eyes = PlushAvatar.eyeOptions.randomElement()?.id ?? draft.eyes
        draft.glasses = PlushAvatar.glassesOptions.randomElement()?.id ?? draft.glasses
        draft.accessory = PlushAvatar.accessoryOptions.randomElement()?.id ?? draft.accessory
        draft.glassesColor = "#222222"
        draft.accessoryColor = "#222222"
        refreshOptionImages()
        refresh()
    }

    private var colorTargetName: String {
        switch selectedTab {
        case .shape, .eyes: "星球"
        case .glasses: "眼镜"
        case .accessory: "配饰"
        }
    }

    private func chooseCustomColor() {
        if customColorPanel != nil {
            closeCustomColor()
            return
        }
        // Keep the input in the editor's window so it stays available while a sheet
        // is already presented, including to keyboard and accessibility clients.
        let panel = NSView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.white.cgColor
        panel.layer?.cornerRadius = 16
        panel.layer?.borderColor = NSColor(white: 0.87, alpha: 1).cgColor
        panel.layer?.borderWidth = 1
        panel.layer?.shadowOpacity = 0.12
        panel.layer?.shadowRadius = 12
        panel.layer?.shadowOffset = NSSize(width: 0, height: -3)
        panel.identifier = NSUserInterfaceItemIdentifier("orbi.look.color-editor")
        panel.setAccessibilityLabel("DIY \(colorTargetName)颜色")
        let title = NSTextField(labelWithString: "DIY \(colorTargetName)颜色")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = PlushEditorButton.ink
        let field = NSTextField(string: selectedColor.uppercased())
        field.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        field.identifier = NSUserInterfaceItemIdentifier("orbi.look.custom-color-entry")
        field.setAccessibilityLabel("HEX 颜色")
        field.delegate = self
        // AppKit can send a text field's action when focus changes. Only the
        // explicit Apply button or the consumed Return command commits a color.
        let hint = NSTextField(labelWithString: "输入 6 位 HEX 色值，毛绒纹理会保留。")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        let cancel = PlushEditorButton()
        cancel.title = "取消"
        cancel.textSize = 13
        cancel.identifier = NSUserInterfaceItemIdentifier("orbi.look.custom-color-cancel")
        cancel.onPress = { [weak self] in self?.closeCustomColor() }
        let apply = PlushEditorButton()
        apply.title = "应用"
        apply.textSize = 13
        apply.style = .pill
        apply.identifier = NSUserInterfaceItemIdentifier("orbi.look.custom-color-apply")
        apply.onPress = { [weak self] in self?.applyCustomColor() }
        for control in [title, field, hint, cancel, apply] {
            control.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(control)
        }
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: palette.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: palette.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: palette.topAnchor, constant: -8),
            panel.heightAnchor.constraint(equalToConstant: 118),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 15),
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            field.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            field.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 9),
            field.widthAnchor.constraint(equalToConstant: 210),
            field.heightAnchor.constraint(equalToConstant: 28),
            apply.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -15),
            apply.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            apply.widthAnchor.constraint(equalToConstant: 62),
            apply.heightAnchor.constraint(equalToConstant: 30),
            cancel.trailingAnchor.constraint(equalTo: apply.leadingAnchor, constant: -9),
            cancel.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            cancel.widthAnchor.constraint(equalToConstant: 50),
            cancel.heightAnchor.constraint(equalToConstant: 30),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -15),
            hint.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 9),
        ])
        customColorPanel = panel
        customColorField = field
        customColorHint = hint
        saveButton.keyEquivalent = ""
        view.window?.makeFirstResponder(field)
        field.selectText(nil)
    }

    private func applyCustomColor() {
        guard let field = customColorField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let hex = PlushAvatar.normalizedHex(text) else {
            customColorHint?.stringValue = "请输入有效的 6 位 HEX 色值，例如 #F667AD。"
            customColorHint?.textColor = .systemRed
            view.window?.makeFirstResponder(field)
            return
        }
        selectColor(hex)
    }

    private func closeCustomColor() {
        guard let customColorPanel else { return }
        let field = customColorField
        self.customColorPanel = nil
        customColorField = nil
        customColorHint = nil
        saveButton.keyEquivalent = "\r"
        if field?.currentEditor() != nil { view.window?.makeFirstResponder(nil) }
        customColorPanel.removeFromSuperview()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === customColorField else { return false }
        switch NSStringFromSelector(commandSelector) {
        case "insertNewline:": applyCustomColor(); return true
        case "cancelOperation:": closeCustomColor(); return true
        default: return false
        }
    }

    private func refresh() {
        if let importedImage { preview.image = importedImage.image }
        else if keepsExistingImage { preview.image = existingImage }
        else { preview.image = PlushAvatar.image(for: draft, side: 600) }
        saveButton.isEnabled = keepsExistingImage || preview.image != nil
        for (index, button) in tabs.enumerated() { button.isChosen = index == selectedTab.rawValue }
        for item in optionButtons { item.button.isChosen = !keepsExistingImage && importedImage == nil && item.id == selectedOption }
        for item in swatches { item.button.isChosen = item.hex.lowercased() == selectedColor.lowercased() }
    }

    private func chooseImage() {
        closeCustomColor()
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = botID == nil ? "选择一张图片作为应用图标。" : L("Choose an image for this bot.")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            if onSave != nil {
                guard let image = NSImage(contentsOf: url), image.isValid else {
                    showError(L("That file could not be read as an image."))
                    return
                }
                importedImage = (url, image)
            } else {
                guard let prepared = Self.prepare(imageAt: url) else {
                    showError(L("That file could not be read as an image."))
                    return
                }
                importedImage = prepared
            }
            keepsExistingImage = false
            refresh()
        }
    }

    private func save() {
        if customColorPanel != nil {
            applyCustomColor()
            guard customColorPanel == nil else { return }
        }
        do {
            if let onSave {
                try onSave(draft.normalized, importedImage?.url)
            } else if let botID, store.bot(botID) != nil {
                if let importedImage {
                    store.setBotAvatar(botID, fileURL: importedImage.url)
                } else if !keepsExistingImage {
                    let url = try PlushAvatar.writePNG(for: draft, side: Int(Self.imageSide))
                    store.setBotAvatar(botID, fileURL: url)
                }
            }
        } catch {
            showError("形象未能保存，请重试。\n\(error.localizedDescription)")
            return
        }
        dismiss(nil)
    }

    override func cancelOperation(_ sender: Any?) {
        if customColorPanel != nil { closeCustomColor() }
        else { dismiss(nil) }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        if let window = view.window { alert.beginSheetModal(for: window) }
        else { alert.runModal() }
    }

    private static func color(hex: String) -> NSColor {
        let number = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x222222
        return NSColor(srgbRed: CGFloat((number >> 16) & 255) / 255, green: CGFloat((number >> 8) & 255) / 255,
                       blue: CGFloat(number & 255) / 255, alpha: 1)
    }

    /// A centered PNG, kept for ordinary uploaded images and the other avatar import callers.
    static func prepare(imageAt url: URL) -> (url: URL, image: NSImage)? {
        guard let source = NSImage(contentsOf: url), source.isValid,
              let representation = source.representations.max(by: { $0.pixelsWide < $1.pixelsWide }) else { return nil }
        let pixelWidth = CGFloat(representation.pixelsWide), pixelHeight = CGFloat(representation.pixelsHigh)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        let side = Int(min(imageSide, min(pixelWidth, pixelHeight)))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let scale = CGFloat(side) / min(pixelWidth, pixelHeight)
        let drawn = NSSize(width: pixelWidth * scale, height: pixelHeight * scale)
        let origin = NSPoint(x: (CGFloat(side) - drawn.width) / 2, y: (CGFloat(side) - drawn.height) / 2)
        source.draw(in: NSRect(origin: origin, size: drawn), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("orbi-avatar-\(UUID().uuidString.lowercased().prefix(8)).png")
        do { try data.write(to: target, options: .atomic) } catch { return nil }
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return (target, image)
    }
}

/// NSButton keeps mouse, Space, Return, focus and VoiceOver behavior while matching the
/// reference editor's simple, borderless controls and rounded selection outlines.
private final class PlushEditorButton: NSButton {
    enum Style { case plain, tile, swatch, pill }
    static let ink = NSColor(srgbRed: 0.105, green: 0.116, blue: 0.12, alpha: 1)
    var style: Style = .plain { didSet { needsDisplay = true } }
    var artwork: NSImage? { didSet { needsDisplay = true } }
    var icon: NSImage? { didSet { needsDisplay = true } }
    var swatchColor: NSColor = .clear { didSet { needsDisplay = true } }
    var textSize: CGFloat = 15
    var isChosen = false {
        didSet {
            state = isChosen ? .on : .off
            setAccessibilityValue(isChosen ? 1 : 0)
            needsDisplay = true
        }
    }
    var onPress: (() -> Void)?

    init() {
        super.init(frame: .zero)
        title = ""
        isBordered = false
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
        target = self
        action = #selector(pressed)
        focusRingType = .exterior
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    @objc private func pressed() { onPress?() }
    override var acceptsFirstResponder: Bool { true }
    override var allowsVibrancy: Bool { false }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: style == .tile ? 15 : 8,
                     yRadius: style == .tile ? 15 : 8).fill()
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
    }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = isEnabled ? (isHighlighted ? 0.7 : 1) : 0.35
        switch style {
        case .tile:
            if let artwork {
                artwork.draw(in: bounds.insetBy(dx: 9, dy: 9), from: .zero, operation: .sourceOver,
                             fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            }
            if isChosen {
                Self.ink.setStroke()
                let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.3, dy: 1.3), xRadius: 16, yRadius: 16)
                border.lineWidth = 2.2
                border.stroke()
            }
        case .swatch:
            swatchColor.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).fill()
            if isChosen {
                Self.ink.setStroke()
                let outline = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.9, dy: 0.9))
                outline.lineWidth = 1.9
                outline.stroke()
            }
        case .pill:
            Self.ink.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
            drawTitle(color: .white, weight: .medium)
        case .plain:
            if let icon {
                let rect = NSRect(x: (bounds.width - icon.size.width) / 2, y: (bounds.height - icon.size.height) / 2,
                                  width: icon.size.width, height: icon.size.height)
                icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha,
                          respectFlipped: true, hints: nil)
            } else {
                drawTitle(color: (isChosen ? Self.ink : NSColor(white: 0.56, alpha: 1)).withAlphaComponent(alpha),
                          weight: isChosen ? .semibold : .regular)
            }
        }
    }

    private func drawTitle(color: NSColor, weight: NSFont.Weight) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: textSize, weight: weight), .foregroundColor: color]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
