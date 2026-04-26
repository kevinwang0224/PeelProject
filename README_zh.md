# Peel

[English README](README.md)

**Peel** 是一款轻量级的 **JSON 格式化与编辑**工具，追求启动快、界面简洁：在 Monaco 中编辑原始 JSON，用 JavaScript 或 JSONPath 做提取，并用可搜索的历史记录管理多份内容，数据在本地持久化。

## 功能概览

- 基于 **Monaco** 的编辑：语法高亮、校验、常用快捷键  
- 粘贴时若内容为合法 **JSON 会自动排版**；非 JSON 则保留原文  
- **提取**：支持内嵌 **JavaScript** 与 **JSONPath**（在后台线程执行，避免阻塞界面）  
- **历史侧栏**：新建、搜索、固定、重命名、删除；编辑会**自动保存**到当前记录  
- **导入/导出**：打开 JSON 文件、导出；剪贴板通过应用壳层读写  
- **主题**：跟随系统、浅色或深色  
- **桌面端**：系统文件对话框与菜单集成（Electron）

## 仓库结构

| 路径 | 说明 |
|------|------|
| [`apps/desktop/`](apps/desktop/) | 当前 **Electron** 桌面应用（React、TypeScript、Vite、Tailwind、shadcn/ui、Monaco） |
| [`packages/shared/`](packages/shared/) | **与平台无关** 的 JSON 工具、提取逻辑、类型与历史相关辅助（`@peel/shared`） |
| `apps/extension/` | 预留的**浏览器扩展**工作区，后续只复用 `@peel/shared` |

界面仅通过预加载层暴露的 **`window.peel`** 小接口访问系统能力，不直接在渲染进程调用 Node 或 Electron API。

## 环境要求

- 推荐 **Node.js 20+**（与当前 Electron / Vite 工具链一致）  
- 使用 **npm**（根目录为 npm workspaces）

## 快速开始

```bash
git clone <你的仓库地址> peel
cd peel
npm install
```

### 开发运行桌面端

```bash
npm run dev:desktop
```

将启动 `@peel/desktop` 工作区（electron-vite）。

### 其他常用根目录脚本

| 命令 | 作用 |
|------|------|
| `npm run build:shared` | 构建 `@peel/shared` |
| `npm run lint` | 为各子包运行 lint（若定义了 `lint`） |
| `npm run test` | 在各子包运行测试 |
| `npm run typecheck` | 各子包类型检查 |
| `npm run build` | 构建各子包（有实现时） |

### 仅桌面端

在仓库根目录：

```bash
npm run test -w @peel/desktop
npm run build -w @peel/desktop
```

`@peel/desktop` 的 `build` 会先构建 `@peel/shared`、做 typecheck 与测试，再打包 Electron 应用。

**macOS 安装包/归档**（详见 `apps/desktop/package.json`）：

```bash
npm run build:mac -w @peel/desktop
```

将生成 DMG 与 ZIP（具体见 `apps/desktop/electron-builder.yml`）。

更细的桌面端说明见 [`apps/desktop/README.md`](apps/desktop/README.md)。

## 技术栈（桌面端）

- [Electron](https://www.electronjs.org/) — 桌面壳  
- [React](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/)  
- [Vite](https://vitejs.dev/) + [electron-vite](https://electron-vite.org/)  
- [Tailwind CSS](https://tailwindcss.com/) + [shadcn/ui](https://ui.shadcn.com/)（Radix 基础组件）  
- [Monaco Editor](https://github.com/microsoft/monaco-editor)  
- 共享逻辑：[jsonc-parser](https://github.com/microsoft/node-jsonc-parser)、[jsonpath-plus](https://github.com/JSONPath-Plus/JSONPath-Plus)

---

*安装包中的产品名：**Peel**（`appId`：`com.peel.desktop`）。*
