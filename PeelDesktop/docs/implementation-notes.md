# PeelDesktop Implementation Notes

`shadcn/ui` 作为组件基础原语，`Tailwind CSS` 管理设计令牌和布局。视觉方向是 macOS 原生极简。

## 视觉方向

macOS 原生极简：像一个系统自带工具。中性灰表面、系统字体、紧凑间距、干净边框。除了用来理清层级的视觉线索，不加任何装饰。

不要做的事：
- 不加网格纹理、噪点、渐变叠加、玻璃拟态
- 不用 editorial / magazine 风格的大标题和衬线字体
- 不用药丸形按钮和输入框（`rounded-full`）
- 不用重阴影和上浮 hover 效果
- 不做入场 stagger 动画

## 设计令牌

### 色板（CSS 变量，定义在 `globals.css`）

| 变量 | 浅色 | 深色 | 用途 |
|------|------|------|------|
| `--background` | `#f5f5f7` | `#1c1c1e` | 页面底色 |
| `--foreground` | `#1d1d1f` | `#f5f5f7` | 主文字 |
| `--muted` | `#86868b` | `#98989d` | 次要文字 |
| `--muted-foreground` | `#98989d` | `#6e6e73` | 辅助文字 / 占位符 |
| `--panel` | `#ffffff` | `#2c2c2e` | 面板 / 卡片背景 |
| `--panel-strong` | `rgba(255,255,255,0.92)` | `rgba(44,44,46,0.92)` | 强面板背景 |
| `--border` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.08)` | 常规边框 |
| `--border-strong` | `rgba(0,0,0,0.12)` | `rgba(255,255,255,0.14)` | 加强边框 |
| `--accent` | `#007aff` | `#0a84ff` | 强调色（macOS 系统蓝） |
| `--accent-foreground` | `#ffffff` | `#ffffff` | 强调色上的文字 |
| `--success` | `#34c759` | `#30d158` | 成功状态 |
| `--danger` | `#ff3b30` | `#ff453a` | 危险状态 |

### 字体

- `--font-sans`：`-apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif`
- `--font-mono`：`"SF Mono", Menlo, Monaco, monospace`
- 不引入 `@fontsource` 或其他第三方字体包

### 圆角

- `--radius-sm`：`0.375rem`（6px）—— 按钮、输入框、下拉项、列表行
- `--radius-md`：`0.5rem`（8px）—— 面板、弹出菜单
- `--radius-lg`：`0.625rem`（10px）—— 对话框

### 阴影

- `--shadow-soft`：`0 1px 3px rgba(0,0,0,0.06)` — tooltip 等小浮层
- `--shadow-panel`：`0 2px 8px rgba(0,0,0,0.06)` — 面板、弹出菜单
- 深色模式下透明度稍高（`0.2`）

## 布局结构

```
grid: 260px sidebar | flexible main area
      ─────────────────────────────────
      sidebar (全高)  | header (auto ~44px)
                      | editor panels (flex)
      ─────────────────────────────────
      status bar (36px, 跨两列)
```

- 侧栏：左侧通栏，`border-right` 分隔，不用面板阴影
- 顶栏：标题 + 工具按钮，`border-bottom` 分隔
- 编辑区：三个面板用 `gap-px` 分隔（1px 间距 = 边框线效果）
- 状态栏：底部通栏，`border-top` 分隔

### 面板头部

- 高度 36px，单行布局
- 左侧：标题（font-medium） + 状态圆点 + 状态文字
- 右侧：操作按钮
- 无 kicker / eyebrow 文字

### 侧栏

- 顶部：app 名称（`text-base font-semibold`）+ 新建按钮
- 搜索框：紧凑，`h-8`，左侧搜索图标
- 列表行：`rounded-md`，选中态用 accent 12% 混合背景
- 底部：Preferences 文字按钮 + 齿轮图标

### 状态栏

- `label: value` 格式，用冒号分隔
- 只有 Validation 指标带状态圆点
- 右侧显示当前主题和字号，纯文字

## 组件使用规范

### Button

| variant | 用途 | 样式要点 |
|---------|------|----------|
| `default` | 主操作 | 前景色填充，无阴影 |
| `outline` | 次要操作 | 边框，透明背景 |
| `ghost` | 工具栏图标 | 无边框，hover 加微妙背景 |
| `accent` | 强调操作（Export） | accent 色填充 |

### Select / DropdownMenu

- focus 态用 `bg-[var(--accent)] text-[var(--accent-foreground)]`（macOS 菜单高亮风格）
- `sideOffset` 用 4-6px
- 内容区 `rounded-lg`，内边距 `p-1`

### Dialog

- overlay 用 `bg-black/30`，不加 blur
- 内容区 `rounded-xl`（12px），宽度上限 480px
- 标题用 `text-base font-semibold`

### Input

- 高度 `h-8`，`rounded-md`
- focus 态 accent 边框 + 2px ring

## Monaco 编辑器主题

两套主题都在 `lib/monaco.ts` 中定义，背景透明。

### peel-light（参考 Xcode 默认）

- 字符串：`#c41a16`（红）
- 数字：`#1c00cf`（蓝紫）
- 关键字：`#9b2393`（紫，加粗）
- 分隔符：`#636366`（灰）
- 光标：`#007aff`（accent 蓝）
- 选区：`#b4d8fd`
- 行号：`#aeaeb2`

### peel-dark（参考 Xcode 暗色）

- 字符串：`#fc6d6b`（粉红）
- 数字：`#d0bf69`（黄）
- 关键字：`#fc5fa3`（粉，加粗）
- 分隔符：`#98989d`（灰）
- 光标：`#0a84ff`（accent 蓝）
- 选区：`#3f638b`
- 行号：`#636366`

## 交互原则

- 不做入场动画，页面加载即完成
- 面板折叠 / 展开用 opacity 过渡（`150ms`）
- hover 态用前景色 4-5% 混合背景，不加边框或阴影变化
- 选中态用 accent 色 12% 混合背景
- 菜单项 focus 用 accent 色实填
- 时间显示用相对时间格式（`formatRelativeTime`），避免秒级跳动
