<p align="center"><img src="macos/Resources/Orbi.png" width="160" alt="Orbi：粉色毛绒星球、星光眼、斜向星环和小卫星" /></p>
<h1 align="center">Orbi</h1>
<p align="center">在 Mac 上，和你的 AI 工作伙伴一起完成任务。</p>
<p align="center">原生 macOS · 智能体协作 · 毛绒星球 DIY · 七款窗口背景</p>

Orbi 是由[李俊祎](https://github.com/17lijunyi)设计并维护的个人 AI 工作台。你可以为不同工作建立智能体，在资料库中找到它们，发起单聊或协作群聊，并从同一个桌面应用管理模型服务、设备与任务。

[源码仓库](https://github.com/17lijunyi/orbi) · [个人网站](https://17lijunyi.github.io/) · [改造记录](docs/ORBI_CHANGES.md) · [架构说明](ARCHITECTURE.md) · [反馈问题](https://github.com/17lijunyi/orbi/issues)

## 一个桌面工作台

- **智能体资料库**：用角色卡片组织智能体，搜索、筛选、查看所在设备，并直接进入聊天。
- **单聊与协作**：为智能体设置名称、职责和模型，在独立会话或群聊中协作，使用任务交接与编排机制。
- **原生 macOS 界面**：主页侧栏管理导航，悬浮胶囊提供便笺、待办、浮窗和创建四个独立操作。便笺与聊天小窗可同时打开；聊天小窗可置顶，和主窗口使用同一段对话。AppKit 工作区和消息输入栏提供中文菜单、设置及内置内容，应用可切换语言。
- **模型与工具**：在账户中连接模型服务商，使用智能体工具、插件和例行任务；本机 CLI 负责运行流程，界面显示消息与工作状态。
- **自己的设备**：通过本地密钥对建立身份，配对电脑与手机，在自己的运行设备上执行任务，并通过端到端加密中继同步账户数据。

## 做一个属于你的 Orbi

Orbi 的形象是一颗有斜向星环和小卫星的毛绒星球。默认使用粉色星球与星光眼，透明底图保留完整轮廓。

在 **设置 → 通用 → App 图标 → 预设与 DIY** 中，可以从 12 张独立随机形状的搭配卡片中选择，或在「形状」页选择 11 种轮廓，再调整星球颜色、眼睛、眼镜与配饰。各形状保留毛绒质感、斜向星环和小卫星；随机搭配会刷新各卡片的形状，同时更换当前预览的形状与搭配。色盘支持输入 HEX 色值，也可以导入自己的图片。保存后更新正在运行的 App 图标，下次启动恢复选择。

智能体也使用同一套形象编辑器：点击资料面板中的头像，或在资料库卡片的右键菜单中选择更改外观。每个智能体可以有自己的形象，保存后会用于卡片与聊天头像。新建智能体时，外观栏提供 8 款不同形状与配色的随机形象，可换一组；创建后使用选中的完整形象。

**设置 → 通用 → 窗口背景** 提供七种选择，点击立即应用并自动保存：

| 背景 | 配色 |
| --- | --- |
| 星雾 | 蓝紫渐变，默认背景 |
| 深湾 | 蓝青渐变 |
| 青苔 | 深绿渐变 |
| 岩茶 | 暖灰褐渐变 |
| 暮莓 | 紫粉渐变 |
| 纯白 | 白色背景与深色文字 |
| 纯黑 | 黑色背景与浅色文字 |

窗口背景决定工作区、导航和输入栏的配色；App 图标与智能体头像有各自的选择。纯白背景使用浅色界面，其余背景使用深色界面，文字、分隔线与聊天气泡随之调整。

## 数据在哪里

macOS 界面通过 localhost WebSocket 连接随 App 打包的 Rust CLI。CLI 管理本地身份、会话、模型调用与任务执行。身份由本地密钥对确定；配对设备通过中继交换加密数据，中继保存公钥与密文。

| 内容 | 保存与同步方式 |
| --- | --- |
| 智能体资料、头像与聊天 | 本地保存，通过账户的端到端加密机制同步到已配对设备 |
| 模型服务商凭证 | 属于账户，以账户密钥加密的 `credentials` 数据同步到已配对设备 |
| 便笺与待办 | 保存在当前 Mac 的应用偏好中，按账户身份分别保存 |
| App 图标与窗口背景 | 保存在当前 Mac 的应用偏好中，开发版与正式版分别保存 |

任务在指定的运行设备上执行，模型请求交给你连接的服务商。具体数据流与加密机制见 [ARCHITECTURE.md](ARCHITECTURE.md)。

## 从源码安装与运行

需要 **macOS 14 或更新版本**、Git、Bun、Rust/Cargo，以及 macOS SDK。Xcode Command Line Tools 可以编译 App；运行 XCTest 需要提供 XCTest 的完整 Xcode。开始前确认 `bun`、`cargo` 和 `swift` 能在终端中运行。

```sh
git clone https://github.com/17lijunyi/orbi.git
cd orbi
bun install
bun run build --debug
open "macos/.build/bundle/debug/Orbi Dev.app"
```

打开开发版后，应用会连接本机 CLI；没有可用服务时会启动随包附带的 CLI。按照首次使用引导创建身份或配对已有设备，再连接模型服务商。模型服务的使用与费用由所连接的服务商决定。

开发版使用 `~/.lorca-dev` 与本地端口 `4863`；正式版使用 `~/.lorca` 与端口 `4862`。这两套账户目录相互独立，通过配对机制连接同一账户的设备。

持续开发使用：

```sh
bun run dev
```

开发脚本监听 Swift、Rust 与资源变化，重新构建并启动 Orbi Dev，同时在 `8787` 端口运行本地开发中继，供设备配对调试使用。修改的源码需要构建到你实际打开的 App 中才会生效。

需要正式版构建时运行 `bun run build`，产物位于 `macos/.build/bundle/release/Orbi.app`。源码构建、Developer ID 签名、公证与分发是不同步骤，发布配置见 [macOS 发布说明](docs/releasing-mac.md)。

### 只预览界面

退出正在运行的 Orbi Dev，然后启动内存演示模式：

```sh
open -n --env LORCA_MOCK=1 "macos/.build/bundle/debug/Orbi Dev.app"
```

演示模式提供示例智能体、聊天和模拟回复；示例账户内容在退出后重置。真实模型会话需要正常启动并连接服务商，App 图标和窗口背景仍属于本机偏好。

## 开发结构

修改前先阅读 [ARCHITECTURE.md](ARCHITECTURE.md)。

| 路径 | 职责 |
| --- | --- |
| `macos/` | 原生 AppKit 界面、形象编辑器、窗口背景与应用资源 |
| `crates/cli/` | 本地服务、账户密钥、设备配对、会话与同步 |
| `crates/agent/` | 智能体循环、模型推理与工具执行 |
| `crates/provider-auth/` | 模型服务商认证 |
| `crates/relay/` | 加密数据中继 |
| `mobile/` | Lorca 手机客户端及共享核心接入 |
| `web/` | Lorca 网站与中英文技术文档源码 |
| `scripts/` | 构建、开发循环、本地化检查与发布脚本 |
| `docs/` | Orbi 改造记录、智能体机制与发布说明 |

毛绒形象的分层素材位于 `macos/Resources/PlushAvatars/`，默认 App 图标为 `macos/Resources/Orbi.png`。更新默认图标后，运行 `bun run scripts/app-icon.ts` 生成 macOS 的 `Orbi.icns`。

## 验证与发布

2026-10-05 的本地验证通过开发版构建、4 项 macOS 启动检查，以及本地化表检查（macOS 835/835、手机端 317/317，均无问题）。形状配置验证覆盖旧配置恢复、新格式往返与图标重启恢复；原生编辑器验证五页布局、独立随机候选、50 次随机切换、精确保存与取消。具体范围见 [改造记录](docs/ORBI_CHANGES.md)。

在本机运行检查：

```sh
bun run l10n
bun run test:mac-startup
swift test --package-path macos  # 需要完整 Xcode / XCTest
```

本仓库以源码构建为主要使用方式。自动更新在发布构建配置 `FEED_URL` 与 `SPARKLE_PUBLIC_KEY` 后启用；开发版通过更新源码并重新构建获得改动。

---

项目维护：[李俊祎 / 17lijunyi](https://github.com/17lijunyi) · [GPL-3.0-only](LICENSE) · [开源声明](NOTICE.md)
