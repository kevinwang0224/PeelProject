# AGENTS.md

用中文回复，表达简单直白，不堆术语。

## 项目定位

`Peel` 是原生 macOS JSON 格式化和编辑工具，目标是轻量、启动快、界面简洁。
- 当前有效工程在 `PeelApp/`
- 应用源码在 `PeelApp/Peel/`
- 旧 `Peel/` 路径在淘汰，后续不要恢复旧目录
- 编辑器方案已切到 `Monaeditor（Monaco）`，不要再按旧 `NSTextView` 主方案设计新功能

## 关键目录

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

- 全局状态集中在 `JSONWorkspace`
- 历史记录使用 SwiftData
- 编辑器主流程基于 `Monaeditor（Monaco）`，不要破坏高亮、错误定位、复制粘贴、查找、运行快捷键
- JSON 处理统一走 `JSONFormatterService`
- JSON 提取统一走 `JSONExtractionService`，支持 JavaScript 和 JSONPath
- 编辑内容会自动写回当前记录，不是手动保存模式
- 当前内容清空后，结束编辑或切换选择时，空记录可能自动删除
- 粘贴内容时会尝试自动格式化；如果不是合法 JSON，就保留原文
- 全局快捷键导入时必须新建记录，不能覆盖当前内容
- 当前内容不是合法 JSON 时，提取功能要明确提示，不能静默失败
- 右侧布局顺序固定：原始 JSON → 提取结果 → 表达式编辑
- 表达式编辑区支持 `Command + Return` 运行

## 开发约定

- 改项目设置、target、构建参数时，优先改 `PeelApp/project.yml`
- 改了项目配置后，记得重新生成工程
- 只要动了功能或工程配置，优先跑 `xcodebuild test`，不要只做 build
- 不要把编辑器主流程改回 `NSTextView`；涉及编辑器改动时，优先在 Monaeditor 方案内完成
- 改动 `PeelApp/Peel/Resources/Monaco/` 时，同步检查许可与声明文件是否需要更新
- 不提交 `build/`、`DerivedData/`、`xcuserdata/`、`.xcuserstate` 等本机生成内容
- 功能范围、目录结构或验证方式变了时，顺手更新本文件

## UI 规范

- Toolbar：用语义化 `placement` 分布；多按钮优先用 `ControlGroup` 或 `ToolbarItemGroup`
- 标题输入框：`.textFieldStyle(.plain)` + `.padding(.leading, 12)`
- Sidebar 搜索：统一用 `.searchable(text:placement:.sidebar)`
- Sidebar 底部固定栏：用 `.safeAreaInset(edge: .bottom)`，背景优先 `.ultraThinMaterial`
- 列表行颜色：只用 `.primary` / `.secondary`，不要硬编码
- 时间显示：优先 `RelativeDateTimeFormatter`，避免秒级跳动
- 行内纵向节奏：`VStack(spacing: 4)` + `.padding(.vertical, 4)`

## 常用命令

```bash
cd /Users/kevin/dev/myprojects/PeelProject/PeelApp
./generate_project.sh

xcodegen generate
xcodebuild -project Peel.xcodeproj -scheme Peel -configuration Debug -derivedDataPath build test
```
