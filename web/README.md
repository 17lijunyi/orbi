# 网站与技术文档源码

这个目录保存 Lorca 的网站与中英文技术文档，随 Orbi 仓库一起维护。Orbi 的产品介绍与源码构建入口见[仓库首页](../README.md)，个人作品展示位于[李俊祎的个人网站](https://17lijunyi.github.io/)。

## 本地运行

在仓库根目录执行：

```sh
bun install
bun run web
```

开发服务监听 `http://localhost:3000`。`bun run web:build` 生成网站构建产物。

## 结构

- `src/routes/`：TanStack Start 文件路由、网站页面与文档搜索接口。
- `src/components/site/`：首页、导航、下载页和功能介绍组件。
- `src/components/docs/`：Fumadocs 文档页面。
- `src/i18n/`：网站中英文文案。
- `content/docs/`：MDX 技术文档，中文文件使用 `.zh.mdx` 后缀。
- `public/`：静态资源、界面截图与 CLI 安装脚本。
- `wrangler.jsonc`：Cloudflare Worker 的名称、入口与运行配置。

网站使用 React、TanStack Start、Vite、Tailwind CSS 和 Fumadocs；Cloudflare Vite 插件生成 Worker 与静态资源。

## 部署

`bun run web:deploy` 构建并部署到当前 Wrangler 配置对应的 Cloudflare 账户。部署前为自己的站点设置 Worker 名称、域名与下载资源地址；现有页面和安装脚本包含 Lorca 的站点与发布入口。

Orbi macOS App 通过根目录的 `bun run build --debug` 构建。网站和原生 App 分别打包，具体进程、账户与同步机制见[架构说明](../ARCHITECTURE.md)。
