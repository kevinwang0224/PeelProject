# AGENTS.md

用中文回复，表达简单直白，不堆术语。

## 项目定位

`Peel` 是 JSON 格式化和编辑工具，目标是轻量、启动快、界面简洁。
- 新版重做工程在 `PeelDesktop/`，技术栈是 `Electron + React + TypeScript + Tailwind CSS + shadcn/ui + Monaco`
- 旧原生工程保留在 `PeelApp/`，主要用于参考和回退，不要把新功能优先做回旧工程
- 当前桌面版应用源码在 `PeelDesktop/src/`
- 原生版应用源码在 `PeelApp/Peel/`
- 旧 `Peel/` 路径在淘汰，后续不要恢复旧目录
- 编辑器主方案统一基于 `Monaco`，不要再按旧 `NSTextView` 主方案设计新功能

## 关键目录

- `PeelDesktop/src/main/`：主进程，窗口、菜单、文件、剪贴板、本地存储
- `PeelDesktop/src/preload/`：预加载桥接，只暴露白名单接口
- `PeelDesktop/src/renderer/src/app/`：主界面与交互
- `PeelDesktop/src/renderer/src/components/`：界面组件与编辑器封装
- `PeelDesktop/src/renderer/src/styles/`：全局主题和样式变量
- `PeelDesktop/src/shared/`：共享类型、JSON 处理、提取逻辑、历史记录工具
- `PeelDesktop/docs/implementation-notes.md`：这次重做的实现说明，包含视觉方向和交互原则
- `PeelDesktop/package.json`：前端和桌面端脚本入口
- `PeelDesktop/electron-builder.yml`：打包配置
- `PeelApp/project.yml`：项目配置源，优先改这里，不直接改 `Peel.xcodeproj`
- `PeelApp/generate_project.sh`：生成并构建工程
- `PeelApp/Peel/App/PeelApp.swift`：应用入口、菜单、全局状态
- `PeelApp/Peel/Models/`：历史记录和文档信息
- `PeelApp/Peel/Services/`：格式化、提取、语法高亮、全局快捷键
- `PeelApp/Peel/Views/Sidebar/`：左侧历史记录
- `PeelApp/Peel/Views/Editor/`：原始 JSON、提取结果、表达式编辑
- `PeelApp/Peel/Views/Editor/MonacoJSONTextEditor.swift`：Monaeditor 的 SwiftUI 封装
- `PeelApp/Peel/Views/Editor/MonacoEditorPool.swift`：编辑器实例池与复用
- `PeelApp/Peel/Resources/Monaco/`：Monaeditor 静态资源与许可文件
- `PeelApp/Peel/Views/Settings/`：设置页
- `PeelApp/PeelTests/`：最小自动检查

## 实现与行为约定

- `PeelDesktop/` 的界面、状态和交互都在 JavaScript 工程里处理，不再依赖原生壳里嵌网页编辑器的旧方案
- `PeelDesktop/` 的系统能力统一通过 `window.peel` 访问，不让界面直接碰 Node 或 Electron API
- 新版历史记录和设置先用本地 JSON 文件存储
- 编辑器主流程基于 `Monaco`，不要破坏高亮、错误定位、复制粘贴、查找、运行快捷键
- JSON 处理统一走 `PeelDesktop/src/shared/json.ts`
- JSON 提取统一走 `PeelDesktop/src/shared/extraction.ts`，支持 JavaScript 和 JSONPath
- 提取执行放后台线程，避免卡住界面
- 编辑内容会自动写回当前记录，不是手动保存模式
- 当前内容清空后，结束编辑或切换选择时，空记录可能自动删除
- 粘贴内容时会尝试自动格式化；如果不是合法 JSON，就保留原文
- 文件导入和剪贴板导入都必须新建记录，不能覆盖当前内容
- 当前内容不是合法 JSON 时，提取功能要明确提示，不能静默失败
- 右侧布局顺序固定：原始 JSON → 提取结果 → 表达式编辑
- 表达式编辑区支持 `Command + Return` 运行

## 开发约定

- 新功能默认优先改 `PeelDesktop/`，只有明确在修原生版问题时才改 `PeelApp/`
- 做 `PeelDesktop/` 时，先看 `PeelDesktop/docs/implementation-notes.md` 里的设计令牌和组件规范，保持 macOS 原生极简风格
- `shadcn/ui` 只当基础件使用，主布局、侧栏、工作区、状态栏必须自己控制
- 改 `PeelDesktop/` 功能或配置后，优先跑：
  - `npm run lint`
  - `npm run test`
  - `npm run typecheck`
  - `npm run build`
- 改项目设置、target、构建参数时，优先改 `PeelApp/project.yml`
- 改了项目配置后，记得重新生成工程
- 只在改动 `PeelApp/` 功能或工程配置时，优先跑 `xcodebuild test`，不要只做 build
- 不要把编辑器主流程改回 `NSTextView`
- 改动 `PeelApp/Peel/Resources/Monaco/` 时，同步检查许可与声明文件是否需要更新
- 不提交 `build/`、`DerivedData/`、`xcuserdata/`、`.xcuserstate` 等本机生成内容
- 不提交 `PeelDesktop/node_modules/`、`PeelDesktop/out/`、`PeelDesktop/dist/` 等生成内容
- 功能范围、目录结构或验证方式变了时，顺手更新本文件

## UI 规范

详细设计令牌和组件约定见 `PeelDesktop/docs/implementation-notes.md`。

### 视觉方向

- 固定为 **macOS 原生极简**：冷灰中性色、系统字体、干净表面、精确间距、克制动效
- 参考 Finder / Notes / Xcode 的视觉语言，不做成后台管理模板
- 不用装饰性纹理、渐变叠加、噪点、玻璃拟态
- 不用紫色渐变白底、满屏卡片、悬浮面板堆叠这类常见套板

### 字体

- UI / 正文：`-apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif`（macOS 系统字体）
- 代码 / 编辑器：`"SF Mono", Menlo, Monaco, monospace`
- 不用 `Inter`、`Arial`、`Roboto`、`Space Grotesk` 等泛用字体
- 不引入第三方 web 字体包，系统字体栈够用

### 色板

- 浅色：背景 `#f5f5f7`、面板 `#ffffff`、强调色 `#007AFF`（macOS 系统蓝）
- 深色：背景 `#1c1c1e`、面板 `#2c2c2e`、强调色 `#0A84FF`
- 成功 / 危险：`#34C759` / `#FF3B30`（浅色）、`#30D158` / `#FF453A`（深色）
- 边框用低透明度的黑或白，不用实色线
- 所有语义色通过 CSS 变量定义在 `globals.css`，通过 `@theme inline` 桥接到 Tailwind

### 圆角

- 小：`0.375rem`（6px）—— 按钮、输入框、下拉项、列表行
- 中：`0.5rem`（8px）—— 面板、弹出菜单、Select 内容区
- 大：`0.625rem`（10px）—— 对话框
- 不要用 `rounded-full`（药丸形），macOS 原生控件不用

### 阴影

- 只用极轻阴影：`0 1px 3px rgba(0,0,0,0.06)` 或 `0 2px 8px rgba(0,0,0,0.06)`
- 深色模式稍重但不夸张
- 不用多层重阴影、`drop-shadow` 叠加、`box-shadow` 发光效果

### 间距与尺寸

- 按钮默认高度 `h-8`（32px），小按钮 `h-7`（28px）
- 输入框高度 `h-8`（32px）
- 面板头部高度 36px，工具栏高度 auto（约 44px），状态栏高度 36px
- 侧栏宽度 260px
- 列表行内边距 `px-2.5 py-2`，文字用 13px
- 用 `gap-px` 或 `gap-1` 分隔面板，不用大间距

### 动效

- 不用入场 stagger 动画
- 面板折叠 / 展开只用 opacity 过渡（`duration: 0.15`）
- hover 和 focus 用微妙的背景色变化（前景色 4-5% 混合），不用边框加粗、glow、上浮
- 选中态用 accent 色 12% 混合背景

### 组件约定

- `shadcn/ui` 只当基础原语使用，不直接用它的默认外观
- 所有组件颜色通过 `var(--xxx)` 引用语义变量，不硬编码 hex
- 弹出菜单 focus 态用 `bg-[var(--accent)] text-[var(--accent-foreground)]`（macOS 风格蓝色高亮）
- dropdown / select 的 `sideOffset` 用 4-6px
- dialog overlay 用 `bg-black/30`，不加 blur
- 状态指示用 6px 圆点（`.peel-status-dot`），不用图标或 badge

### Monaco 编辑器

- 背景透明（`#00000000`），继承面板背景
- 语法色浅色模式参考 Xcode 默认（字符串红、数字蓝、关键字紫）
- 语法色深色模式参考 Xcode 暗色（字符串粉、数字黄、关键字粉）
- 光标和选区颜色跟随 `--accent` 色系
- 主题定义在 `lib/monaco.ts`，名称 `peel-light` / `peel-dark`

## 常用命令

```bash
cd /Users/kevin/dev/myprojects/PeelProject/PeelDesktop
npm install
npm run lint
npm run test
npm run typecheck
npm run build

cd /Users/kevin/dev/myprojects/PeelProject/PeelApp
./generate_project.sh

xcodegen generate
xcodebuild -project Peel.xcodeproj -scheme Peel -configuration Debug -derivedDataPath build test
```
