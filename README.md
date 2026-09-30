<p align="center"><img src="macos/Resources/Orbi.png" width="128" alt="Orbi 星环图标" /></p>
<h1 align="center">Orbi</h1>
<p align="center">让一支 AI 团队，住进你的 Mac。</p>
<p align="center">中文体验 · 悬浮玻璃界面 · 智能体协作 · 本地运行</p>

我是[李俊祎](https://github.com/17lijunyi)。Orbi 是我设计并持续迭代的个人 AI 工作台：把智能体、聊天和模型服务放进一个轻盈的桌面空间，让日常工作有清晰的入口。

这个项目基于 [EGOIST / Lorca](https://github.com/egoist/lorca) 开源项目开发。我负责 Orbi 的产品呈现、桌面界面重构、中文体验与品牌设计；智能体运行、设备配对和加密同步沿用 Lorca 的技术基础。项目保留上游历史，以 **GPL-3.0-only** 开源。

[个人网站](https://17lijunyi.github.io/) · [源码仓库](https://github.com/17lijunyi/orbi) · [改造记录](docs/ORBI_CHANGES.md) · [架构说明](ARCHITECTURE.md)

## 为什么做 Orbi

我希望 AI 助手能像桌面上的工作伙伴：可以按职责找到它，也能把相关成员放进同一段对话。Orbi 围绕这个想法，把入口做成智能体卡片，用悬浮导航切换场景，用独立的消息栏承接对话。

## 当前体验

- **智能体资料库**：卡片展示角色与所在设备，支持搜索、筛选和打开聊天。
- **悬浮玻璃工作区**：原生 AppKit 窗口、macOS 背景模糊、悬浮导航与消息输入栏。
- **统一中文界面**：菜单、设置、智能体介绍、市场内容与内置演示聊天均提供中文文案；也可切换英语。
- **单聊与协作群聊**：使用 Lorca 的智能体会话、任务交接和群聊机制。
- **账户与设备**：身份使用本地密钥对，已配对设备通过端到端加密中继同步；模型服务商凭证作为账户加密数据同步。
- **Orbi 星环图标**：深色底与珠光星环铺满图标画布，在 Dock、关于窗口和欢迎页使用同一套图标。

## 从源码运行

需要 macOS 14 或更新版本、Bun、Rust 与 macOS SDK。可以使用 Xcode Command Line Tools 编译 App；运行 XCTest 单元测试需要完整 Xcode。

```sh
git clone https://github.com/17lijunyi/orbi.git
cd orbi
bun install
bun run build --debug
open "macos/.build/bundle/debug/Orbi Dev.app"
```

正常打开开发版会连接并启动本地命令行服务。首次使用按应用内引导创建身份或配对设备，再连接模型服务商。第三方模型服务按各自规则计费。

想先看界面，可以退出正在运行的 Orbi Dev，再打开内存演示模式：

```sh
open -n --env LORCA_MOCK=1 "macos/.build/bundle/debug/Orbi Dev.app"
```

演示模式包含示例智能体、聊天和模拟回复，退出后重置。它适合预览界面，不代表已经连接真实模型。

持续开发可运行 `bun run dev`。开发循环重编译 Swift / Rust 改动并重新启动应用，同时在本机启动开发中继。开发账户保存在 `~/.lorca-dev`，本地服务端口为 `4863`；底层命令、目录和协议标识使用 Lorca 命名。

## 目录

| 路径 | 内容 |
| --- | --- |
| `macos/` | Orbi 原生 macOS 界面、中文资源与图标 |
| `crates/cli/` | Lorca 本地服务、身份、配对与会话数据 |
| `crates/agent/` | 智能体循环与模型服务商适配 |
| `crates/relay/` | 加密数据中继 |
| `mobile/` | Lorca 手机客户端源码 |
| `web/` | 上游网站和技术文档源码 |
| `scripts/` | 构建、开发与图标打包脚本 |

## 验证与发布状态

当前提供可编译的源码开发版。已在 Apple Silicon Mac 上通过开发版构建、4 项启动检查和 854 条 macOS 本地化文案检查，并检查了首页、聊天、市场、设置和图标的实际显示。

```sh
bun run l10n
bun run test:mac-startup
swift test --package-path macos  # 需要完整 Xcode / XCTest
```

当前没有发布签名、公证的 Orbi 安装包。应用内自动更新仅在构建时提供 Orbi 自己的 `FEED_URL` 和 `SPARKLE_PUBLIC_KEY` 后启用；源码开发版可通过 Git 拉取更新并重新编译。图标源文件为 `macos/Resources/Orbi.png`，运行 `bun run scripts/app-icon.ts` 可生成 `Orbi.icns`。

## 来源与许可

- 上游：[egoist/lorca](https://github.com/egoist/lorca)，作者及贡献者的提交历史保留在本仓库中。
- Orbi 改造：李俊祎，始于 2026-09-30；本次开源整理日期为 2026-10-01，详见 [Orbi 改造记录](docs/ORBI_CHANGES.md)。
- 图标：根据 Orbi 品牌方向使用 AI 图像工具生成并整理为 macOS 图标资源。
- 许可：[GNU GPL v3](LICENSE)，代码许可标识为 `GPL-3.0-only`。上游版权与许可声明继续有效。

欢迎通过 [Issues](https://github.com/17lijunyi/orbi/issues) 反馈使用体验或提出改进建议。
