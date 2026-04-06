# AGENTS.md

## 沟通方式

- 向用户汇报时，用中文、简单直白的语言说明做了什么、结果怎样、还差什么。
- 最终回复不要堆术语，不要写成代码说明书。

## 项目定位

- 这是一个原生 macOS JSON 格式化和编辑工具，项目名是 `Peel`。
- 目标很明确：轻量、启动快、界面简洁、零第三方依赖，只用 Apple 自带框架。
- 当前有效工程在 `PeelApp/`，真正的应用源码在 `PeelApp/Peel/`。

## 当前仓库现状

- 仓库正在经历一次目录迁移：旧的 `Peel/` 路径在删除，新的内容在 `PeelApp/`。
- 后续工作默认都基于 `PeelApp/`，不要把旧 `Peel/` 目录或旧路径误恢复回来。
- `PeelApp/README.md` 里的构建说明还带有旧路径痕迹，实际操作以当前目录结构为准。

## 目录速览

- `PeelApp/project.yml`：XcodeGen 的项目源文件，项目配置以这里为准。
- `PeelApp/generate_project.sh`：一键生成并构建工程的脚本。
- `PeelApp/Peel/App/PeelApp.swift`：应用入口、菜单命令、全局工作区状态。
- `PeelApp/Peel/Models/`：数据模型，当前主要是历史记录和 JSON 文档信息。
- `PeelApp/Peel/Services/`：JSON 格式化、提取、语法高亮、全局快捷键等核心能力。
- `PeelApp/Peel/Views/Sidebar/`：左侧历史记录区。
- `PeelApp/Peel/Views/Editor/`：原始 JSON、提取结果区、表达式编辑区和状态反馈。
- `PeelApp/Peel/Views/Settings/`：设置页，当前包括 Quick Paste 快捷键设置。
- `PeelApp/Peel/Extensions/`：字符串和颜色的小扩展。
- `PeelApp/PeelTests/`：当前最小自动检查，主要覆盖 JSON 提取和快捷键校验。

## 关键实现认知

- 应用是 macOS 专用，不是通用 SwiftUI 模板，里面直接用了 `AppKit` 的剪贴板、打开/保存面板、`NSTextView` 等能力。
- 全局状态集中在 `JSONWorkspace`，它负责当前选中项、编辑内容、导入导出、菜单动作和历史清理。
- 历史记录通过 `SwiftData` 保存，核心数据是标题、原始 JSON、格式化后的 JSON、更新时间和置顶状态。
- 编辑器不是系统默认文本框，而是包了一层 `NSTextView`，语法高亮和错误定位都依赖这层实现。
- JSON 处理统一走 `JSONFormatterService`，支持格式化、压缩、校验，并给出错误行列位置。
- JSON 提取统一走 `JSONExtractionService`，当前支持 `JavaScript` 和 `JSONPath` 两种模式。
- 全局 Quick Paste 由专门的控制器负责，快捷键可自定义，触发后会尝试把应用拉到前台并从剪贴板新建一条记录。

## 改动时要注意的行为

- 编辑区内容会自动写回当前记录，不是只有点“保存”才生效。
- 如果当前内容被清空，结束编辑或切换选择时，空记录可能会被自动删除。
- 粘贴内容时会尝试自动整理成漂亮格式；如果不是合法 JSON，就保留原文。
- 导入 `.json` 文件的逻辑很直接：读入文本，创建一条新记录，再保存。
- 错误提示不仅显示是否合法，还会高亮对应行和问题片段；改编辑器时不要破坏这套反馈。
- 通过全局快捷键导入时，应该始终新建记录，不要覆盖用户当前正在编辑的内容。
- 当前右侧内容区是自上而下三段式：原始 JSON、提取结果区、表达式编辑区；调整布局时不要改乱这个顺序。
- 表达式编辑区支持 `Command + Return` 直接运行，`Run` 按钮上也会显示这个提示。
- 当当前内容不是合法 JSON 时，提取功能应该明确提示不可执行，而不是静默失败。

## 开发约定

- 修改项目设置、target 或构建参数时，优先改 `PeelApp/project.yml`，不要只改生成出来的 `Peel.xcodeproj`。
- 如果改了项目配置，记得重新生成工程文件。
- 这个仓库现在已经有一组最小自动检查；只要动了功能或工程配置，优先跑一次 `xcodebuild test`，不要只做 build。
- 继续保持“零第三方依赖”的方向，优先使用系统框架现有能力。
- 这是桌面工具项目，做改动时优先守住稳定和顺手，不要为了“更通用”把现有交互复杂化。
- 不要提交本机生成内容和个人状态文件，比如 `build/`、`DerivedData/`、`xcuserdata/`、`.xcuserstate` 一类。

## 常用命令

```bash
cd /Users/kevin/dev/myprojects/PeelProject/PeelApp
./generate_project.sh
```

```bash
cd /Users/kevin/dev/myprojects/PeelProject/PeelApp
xcodegen generate
xcodebuild -project Peel.xcodeproj -scheme Peel -configuration Debug -derivedDataPath build test
```

## 补充说明

- 根目录的 `logo_v2.png` 目前更像设计资源，不属于主构建链路；动它之前先确认是否真的要接入应用资源。
- 根目录的 `AGENTS.md` 是给后续协作看的项目说明，功能范围、目录认知和验证方式变了时，要顺手一起更新。
