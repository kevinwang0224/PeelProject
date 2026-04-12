# Peel 重做方案（Electron + Tailwind CSS + shadcn/ui，强制参考 frontend-design）

## Summary

- 新版本改成完整的 JavaScript 桌面应用：`Electron + React + TypeScript + Vite + Tailwind CSS + shadcn/ui + Monaco`。
- 实现前和实现中都必须参考 `frontend-design` skill：[/Users/kevin/.agents/skills/frontend-design/SKILL.md](/Users/kevin/.agents/skills/frontend-design/SKILL.md)。
- 目标不只是“能用”，而是做成一款有明确审美方向的现代桌面工具：专业、克制、锋利，不做模板味，不做默认组件拼装感。
- 第一版范围固定：编辑、格式化、提取、历史、打开/导出文件、系统主题跟随；不迁移旧数据，不做全局快捷键。

## Design Directives

- 开始实现前，先按 `frontend-design` skill 产出 3 个固定设计决策，并写进实现说明：
  - `visual thesis`：一句话定视觉气质
  - `content plan`：每个区域各自承担什么职责
  - `interaction thesis`：2 到 3 个关键动效
- 本项目的视觉方向直接定为：
  - `industrial editorial`：像现代开发工具和高质量杂志版式的结合，冷静、精确、有秩序，但不呆板。
- 必须遵守这些落地要求：
  - `shadcn/ui` 只当基础件，不允许整页照搬默认样式
  - `Tailwind` 负责主题变量、间距、层级、状态样式
  - 主布局、侧栏、编辑区、状态栏必须自定义，不做成通用后台
  - 不用 `Inter`、`Arial`、`Roboto`、系统默认无趣搭配
  - 不用紫色渐变白底这类常见套板
  - 不做满屏卡片和悬浮小面板堆叠
- 字体要求：
  - 界面字体选一组更有性格的正文字体
  - 代码区单独用等宽字体
  - 标题和功能文字层级要明显，但不能压过内容本身
- 动效要求：
  - 首屏与主工作区进入时有一次统一的轻动效
  - 侧栏切换、结果展开、表达式运行反馈要有短促过渡
  - 动效以增强层级和状态为目的，不做花哨装饰

## Implementation Changes

- 桌面壳
  - 主进程负责窗口、菜单、文件对话框、剪贴板和生命周期。
  - 预加载层只暴露白名单接口，不让界面直接接系统能力。
  - 渲染层只写 React 界面和交互。
- 前端结构
  - 左侧：历史列表、搜索、新建、设置入口。
  - 右侧上方：原始 JSON 编辑区。
  - 右侧中部：提取结果区。
  - 右侧下方：表达式编辑区。
  - 底部：状态栏，显示校验、类型、大小、条目数。
- 编辑体验
  - 原始 JSON 和表达式区继续用 Monaco。
  - 提取结果如果是结构化内容，用只读编辑器；普通文本用轻量文本区。
  - 保留现有产品规则：
    - 粘贴合法 JSON 自动整理
    - 非法内容原样保留
    - `Command + Return` 运行表达式
    - 非法 JSON 时提取区明确提示
    - 清空内容后，失焦或切换记录时删掉空记录
- 数据与本地存储
  - 历史和设置先放本地文件存储。
  - 历史项固定字段：`id / title / content / createdAt / updatedAt / pinned`
  - 自动保存继续用短延迟写盘。
- 提取能力
  - `JavaScript` 和 `JSONPath` 都保留。
  - 放到独立后台线程执行，防止卡界面。
  - `JavaScript` 只暴露只读 `data`。
  - 每次执行都有超时，超时直接停掉并提示。

## Public Interfaces

- `window.peel.bootstrap()`
- `window.peel.history.create()`
- `window.peel.history.save(record)`
- `window.peel.history.rename(id, title)`
- `window.peel.history.remove(id)`
- `window.peel.history.togglePin(id)`
- `window.peel.files.openJson()`
- `window.peel.files.exportJson({ suggestedName, content })`
- `window.peel.clipboard.readText()`
- `window.peel.clipboard.writeText(text)`
- `window.peel.menu.onAction(listener)`

## Test Plan

- 逻辑检查
  - 格式化、压缩、错误定位、粘贴自动整理、提取结果、空结果、超时提示。
- 存储检查
  - 新建、重命名、置顶、删除、自动保存、空记录清理。
- 交互检查
  - 搜索历史、切换记录、展开收起、运行表达式、复制结果。
- 视觉验收
  - 浅色和深色都成立，层级统一，不像默认模板。
  - `shadcn/ui` 痕迹不能过重，看起来必须像专门为 Peel 设计。
  - 侧栏、工作区、状态栏、面板头部要有统一气质，不像东拼西凑。
- 桌面体验
  - 触控板轻点、拖选、双击选词、复制粘贴、查找都稳定。
  - 长文本、窄窗口、高分屏下不乱。

## Assumptions

- 新工程单独放在 `PeelDesktop/`，旧 `PeelApp/` 暂时保留。
- 第一版不迁移旧历史数据。
- 第一版不做全局快捷键和自动更新。
- 实现时如果 `shadcn/ui` 默认样式和 `frontend-design` skill 冲突，以 `frontend-design` skill 为准，只保留组件能力，不保留默认观感。