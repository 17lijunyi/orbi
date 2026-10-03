# Orbi 改造记录

维护者：[李俊祎 / 17lijunyi](https://github.com/17lijunyi)

更新日期：2026-10-03

Orbi 从 [egoist/lorca](https://github.com/egoist/lorca) 的 `9e5624fb8147d773f62822d58edcc7d6cc2954f2` 继续开发，保留上游提交历史、作者署名与 GPL-3.0-only 许可证。本文记录 Orbi 当前提供的桌面体验及相应实现。

## 原生桌面工作台

Orbi 的 macOS 应用使用 AppKit。主窗口由悬浮导航、圆角工作区和独立消息输入栏组成；智能体资料库使用角色卡片，提供搜索、筛选、设备信息和聊天入口。聊天、设置、市场与弹窗共用视觉层级。

应用显示名、菜单与欢迎流程使用 Orbi。界面提供中文菜单、设置、内置角色、设备文案、示例会话与市场介绍，并保留应用语言切换。新增形象编辑器和窗口背景选项使用中文文案。底层 Swift 包、CLI 和协议沿用 Lorca 命名，与其账户和设备机制保持一致。

## 毛绒星球形象

默认形象为粉色毛绒星球：星光眼、斜向星环与右上方小卫星，PNG 使用透明背景。资料库和聊天头像按完整轮廓显示。

原生形象编辑器包含 12 款预设：星光粉、粉色绅士、蓝色画家、柠檬学者、紫色墨镜、青柠好奇心、珊瑚魔术师、天空音乐家、薄荷小王子、兰紫绒球、奶油小呆毛和薰衣草漫步。

用户可以从预设开始，组合眼睛、眼镜与配饰，分别调整星球、眼镜、配饰的颜色，输入 HEX 色值，随机搭配，或导入图片。预览在编辑器内更新，保存才应用，取消保留已有选择。毛绒质感由透明分层素材合成，配色调整保留材质明暗。

同一个编辑器有两处入口，保存范围不同：

| 入口 | 应用范围 | 保存方式 |
| --- | --- | --- |
| 设置 → 通用 → App 图标 → 预设与 DIY | 当前 Mac 上的 Orbi App 图标及应用内图标预览 | 本地偏好保存配置，导入图片保存在应用支持目录；启动时恢复 |
| 智能体资料面板头像，或资料库卡片右键菜单 | 该智能体的卡片、聊天与资料头像 | 写入 512 px PNG，经 `bots.update.avatar` 保存为加密附件并同步到已配对设备 |

智能体头像的版本化文件名记录颜色与部件选择，使配对 Mac 可以恢复可编辑的组合。App 图标使用 `NSApp.applicationIconImage` 更新运行中的图标；打包图标来自 `macos/Resources/Orbi.png` 和 `Orbi.icns`。开发版与正式版分别保存各自的本地图标偏好。

相关实现：

- `macos/Sources/Lorca/Design/PlushAvatar.swift`：形象配置、分层合成与 PNG 导出。
- `macos/Sources/Lorca/Sheets/BotLookViewController.swift`：预设、DIY、随机与导入编辑器。
- `macos/Sources/Lorca/App/AppIcon.swift`：本地图标偏好与应用图标更新。
- `macos/Resources/PlushAvatars/`：毛绒星球、眼睛、眼镜和配饰素材。
- `scripts/artwork/README.md`：素材制作与部件对齐约定。

## 七款窗口背景

设置 → 通用 → 窗口背景提供星雾、深湾、青苔、岩茶、暮莓、纯白与纯黑。前五款为三色对角渐变，后两款为纯色。设置页以 4+3 两行微型窗口预览展示选项，支持点击、方向键、空格与辅助功能，也可通过设置搜索定位。

背景选择立即应用到工作区、导航、消息输入栏、弹窗与欢迎界面，并写入当前应用的 UserDefaults。默认背景为星雾；纯白使用 Aqua，其余使用 Dark Aqua，文字、分隔线和聊天气泡同步调整对比度。重启恢复上次选择。

窗口背景与 App 图标、智能体头像分别设置。窗口表面绘制所选配色，悬浮表面之间的间隙透出桌面。

相关实现为 `Design/WindowBackground.swift`、`Design/SpatialChrome.swift`、`Design/Theme.swift` 与 `Settings/WindowBackgroundPicker.swift`，路径均相对于 `macos/Sources/Lorca/`。

## 本地运行与加密同步

Orbi 的 AppKit 界面连接本机 Rust CLI，CLI 随应用打包并由应用按需启动。智能体循环、模型服务商适配、工具与插件、例行任务、群聊协作和任务交接使用 Lorca 的实现。

身份是本地密钥对。配对设备通过端到端加密中继同步账户数据；模型服务商凭证属于账户，作为账户密钥加密的 `credentials` 数据同步。智能体头像以加密文件附件同步，App 图标与窗口背景保存在各设备本地。完整机制见 [ARCHITECTURE.md](../ARCHITECTURE.md)。

## 构建与验证

`bun run build --debug` 构建 Orbi Dev，`bun run build` 构建 Orbi。构建脚本在 Command Line Tools 环境下打包 Markdown 静态库与 UniFFI 头文件，并将毛绒分层素材与图标放入应用包。`scripts/app-icon.ts` 从默认 PNG 生成十种标准 macOS 图标规格。

截至本文更新，开发版在 Apple Silicon Mac 上完成构建；毛绒编辑器与窗口背景使用原生界面检查。背景选择器另外通过独立 AppKit 布局检查，覆盖 560 px 与 1000 px 宽窗口，验证七个选项的布局及窗口宽度保持。

本轮 `bun run test:mac-startup` 的 4 项检查全部通过；`bun run l10n` 检查 macOS 835 条与手机端 317 条本地化表文案，均无缺失、占位符不一致或未使用条目。Swift XCTest 使用 `swift test --package-path macos`，需要提供 XCTest 的完整 Xcode，不计入上述验证结果。源码构建与检查不替代发布包的签名、公证和分发验证。

发布构建通过显式配置的 `FEED_URL`、`SPARKLE_PUBLIC_KEY` 启用 Sparkle 更新；发布步骤见 [macOS 发布说明](releasing-mac.md)。

## 贡献与许可

Lorca 的上游作者 EGOIST 及贡献者提供本地服务、智能体运行、密钥身份、配对、加密同步、模型服务商接入、插件与手机客户端等技术基础。Orbi 的产品设计、macOS 界面改造、中文体验、毛绒星球形象及个性化设置由李俊祎主导，使用 AI 工具辅助实现与素材制作。

本仓库保留这些技术来源及提交历史，按 [GPL-3.0-only](../LICENSE) 提供源码。上游版权与许可声明继续有效。
