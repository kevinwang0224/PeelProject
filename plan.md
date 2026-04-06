

# macOS JSON 编辑器 — Codex 执行规划

## 项目概述

构建一个原生 macOS JSON 格式化/编辑工具，使用 Swift + SwiftUI，要求内存占用小、启动快、界面简洁美观。

---

## 技术约束

* **语言**：Swift 5.9+
* **框架**：SwiftUI，最低部署目标 macOS 14.0 (Sonoma)
* **持久化**：SwiftData
* **JSON 处理**：Foundation.JSONSerialization
* **语法高亮**：基于 NSTextView 手动实现（零第三方依赖）
* **包管理**：不使用 SPM / CocoaPods，全部使用系统框架
* **构建**：Xcode project（通过 `xcodebuild` 命令行构建）

---

## 目录结构

```
JSONMaster/
├── JSONMaster.xcodeproj/
├── JSONMaster/
│   ├── App/
│   │   └── JSONMasterApp.swift
│   ├── Models/
│   │   ├── JSONDocument.swift
│   │   └── HistoryItem.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── Sidebar/
│   │   │   ├── SidebarView.swift
│   │   │   └── HistoryRowView.swift
│   │   └── Editor/
│   │       ├── EditorContainerView.swift
│   │       ├── JSONTextEditor.swift
│   │       └── StatusBarView.swift
│   ├── Services/
│   │   ├── JSONFormatterService.swift
│   │   └── SyntaxHighlighter.swift
│   ├── Extensions/
│   │   ├── Color+Theme.swift
│   │   └── String+JSON.swift
│   └── Resources/
│       └── Assets.xcassets/
│           ├── AccentColor.colorset/
│           │   └── Contents.json
│           ├── AppIcon.appiconset/
│           │   └── Contents.json
│           └── Contents.json
└── README.md
```

---

## 任务分解

### Task 1：初始化项目骨架

创建 Xcode 项目结构和所有文件。

**文件：`JSONMaster/JSONMaster/App/JSONMasterApp.swift`**

```swift
import SwiftUI
import SwiftData

@main
struct JSONMasterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: HistoryItem.self)
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 650)
    }
}
```

**文件：`JSONMaster/JSONMaster/Resources/Assets.xcassets/Contents.json`**

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**文件：`JSONMaster/JSONMaster/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`**

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.996",
          "green" : "0.557",
          "red" : "0.220"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "1.000",
          "green" : "0.647",
          "red" : "0.380"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**文件：`JSONMaster/JSONMaster/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`**

```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

---

### Task 2：数据模型层

**文件：`JSONMaster/JSONMaster/Models/HistoryItem.swift`**

```swift
import Foundation
import SwiftData

@Model
final class HistoryItem {
    var id: UUID
    var title: String
    var rawJSON: String
    var formattedJSON: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(
        title: String = "Untitled",
        rawJSON: String,
        formattedJSON: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.rawJSON = rawJSON
        self.formattedJSON = formattedJSON
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
    }
}
```

**文件：`JSONMaster/JSONMaster/Models/JSONDocument.swift`**

```swift
import Foundation

struct JSONDocument {
    enum JSONType: String {
        case object = "Object"
        case array = "Array"
        case string = "String"
        case number = "Number"
        case boolean = "Boolean"
        case null = "Null"
        case unknown = "Unknown"
    }

    let raw: String
    let formatted: String
    let type: JSONType
    let size: Int
    let keyCount: Int

    init(raw: String) {
        self.raw = raw
        self.size = raw.utf8.count

        guard let data = raw.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            self.formatted = raw
            self.type = .unknown
            self.keyCount = 0
            return
        }

        if let dict = jsonObject as? [String: Any] {
            self.type = .object
            self.keyCount = dict.count
        } else if let arr = jsonObject as? [Any] {
            self.type = .array
            self.keyCount = arr.count
        } else {
            self.type = .unknown
            self.keyCount = 0
        }

        if let prettyData = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        ), let prettyString = String(data: prettyData, encoding: .utf8) {
            self.formatted = prettyString
        } else {
            self.formatted = raw
        }
    }
}
```

---

### Task 3：JSON 格式化服务

**文件：`JSONMaster/JSONMaster/Services/JSONFormatterService.swift`**

```swift
import Foundation

enum JSONFormatStyle {
    case pretty
    case compact
    case sortedKeys
}

enum JSONError: LocalizedError {
    case invalidJSON(String)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail):
            return "Invalid JSON: \(detail)"
        case .encodingError:
            return "Failed to encode JSON string"
        }
    }
}

struct JSONFormatterService {

    static func format(_ input: String, style: JSONFormatStyle = .pretty) -> Result<String, JSONError> {
        guard let data = input.data(using: .utf8) else {
            return .failure(.encodingError)
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }

        var options: JSONSerialization.WritingOptions = []
        switch style {
        case .pretty:
            options = [.prettyPrinted, .sortedKeys]
        case .compact:
            options = []
        case .sortedKeys:
            options = [.prettyPrinted, .sortedKeys]
        }

        do {
            let outputData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
            guard let output = String(data: outputData, encoding: .utf8) else {
                return .failure(.encodingError)
            }
            return .success(output)
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    static func validate(_ input: String) -> Bool {
        guard let data = input.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil
    }

    static func minify(_ input: String) -> Result<String, JSONError> {
        return format(input, style: .compact)
    }
}
```

---



### Task 4（续）：语法高亮引擎

**文件：`JSONMaster/JSONMaster/Services/SyntaxHighlighter.swift`**（完整版）

```swift
import AppKit
import Foundation

struct SyntaxHighlighter {

    struct Theme {
        let key: NSColor
        let string: NSColor
        let number: NSColor
        let boolean: NSColor
        let null: NSColor
        let brace: NSColor
        let background: NSColor
        let defaultText: NSColor

        static let light = Theme(
            key: NSColor(red: 0.16, green: 0.30, blue: 0.60, alpha: 1.0),
            string: NSColor(red: 0.76, green: 0.24, blue: 0.16, alpha: 1.0),
            number: NSColor(red: 0.11, green: 0.51, blue: 0.47, alpha: 1.0),
            boolean: NSColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0),
            null: NSColor.systemGray,
            brace: NSColor.labelColor,
            background: NSColor.textBackgroundColor,
            defaultText: NSColor.labelColor
        )

        static let dark = Theme(
            key: NSColor(red: 0.58, green: 0.79, blue: 0.93, alpha: 1.0),
            string: NSColor(red: 0.81, green: 0.56, blue: 0.42, alpha: 1.0),
            number: NSColor(red: 0.71, green: 0.84, blue: 0.59, alpha: 1.0),
            boolean: NSColor(red: 0.78, green: 0.57, blue: 0.86, alpha: 1.0),
            null: NSColor.systemGray,
            brace: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0),
            background: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0),
            defaultText: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        )
    }

    static func highlight(_ json: String, theme: Theme, font: NSFont) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: json,
            attributes: [
                .foregroundColor: theme.defaultText,
                .font: font
            ]
        )

        let text = json as NSString
        let fullRange = NSRange(location: 0, length: text.length)

        // Highlight string keys: "key" :
        let keyPattern = "\"([^\"\\\\]|\\\\.)*\"\\s*:"
        if let regex = try? NSRegularExpression(pattern: keyPattern) {
            let matches = regex.matches(in: json, range: fullRange)
            for match in matches {
                var range = match.range
                let matchedStr = text.substring(with: range)
                if let colonIndex = matchedStr.lastIndex(of: ":") {
                    let offset = matchedStr.distance(from: matchedStr.startIndex, to: colonIndex)
                    range.length = offset
                }
                attributed.addAttribute(.foregroundColor, value: theme.key, range: range)
            }
        }

        // Highlight string values: : "value"
        let stringValuePattern = ":\\s*\"([^\"\\\\]|\\\\.)*\""
        if let regex = try? NSRegularExpression(pattern: stringValuePattern) {
            let matches = regex.matches(in: json, range: fullRange)
            for match in matches {
                let matchedStr = text.substring(with: match.range)
                if let quoteIndex = matchedStr.firstIndex(of: "\"") {
                    let offset = matchedStr.distance(from: matchedStr.startIndex, to: quoteIndex)
                    let valueRange = NSRange(
                        location: match.range.location + offset,
                        length: match.range.length - offset
                    )
                    attributed.addAttribute(.foregroundColor, value: theme.string, range: valueRange)
                }
            }
        }

        // Highlight string values in arrays
        let arrayStringPattern = "(?<=\\[\\s{0,100}|,\\s{0,100})\"([^\"\\\\]|\\\\.)*\""
        if let regex = try? NSRegularExpression(pattern: arrayStringPattern) {
            let matches = regex.matches(in: json, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: theme.string, range: match.range)
            }
        }

        // Highlight numbers
        let numberPattern = "(?<=:\\s{0,10}|\\[\\s{0,10}|,\\s{0,10})-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?"
        if let regex = try? NSRegularExpression(pattern: numberPattern) {
            let matches = regex.matches(in: json, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: theme.number, range: match.range)
            }
        }

        // Highlight booleans
        let boolPattern = "\\b(true|false)\\b"
        if let regex = try? NSRegularExpression(pattern: boolPattern) {
            let matches = regex.matches(in: json, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: theme.boolean, range: match.range)
            }
        }

        // Highlight null
        let nullPattern = "\\bnull\\b"
        if let regex = try? NSRegularExpression(pattern: nullPattern) {
            let matches = regex.matches(in: json, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: theme.null, range: match.range)
            }
        }

        // Highlight braces and brackets
        let bracePattern = "[\\{\\}\\[\\]]"
        if let regex = try? NSRegularExpression(pattern: bracePattern) {
            let matches = regex.matches(in: json, range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: theme.brace, range: match.range)
            }
        }

        return attributed
    }

    static func currentTheme() -> Theme {
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }
}
```

---

### Task 5：扩展工具

**文件：`JSONMaster/JSONMaster/Extensions/Color+Theme.swift`**

```swift
import SwiftUI

extension Color {
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let editorBackground = Color(nsColor: .textBackgroundColor)
    static let subtleText = Color(nsColor: .secondaryLabelColor)
    static let accent = Color.accentColor
    static let errorRed = Color(nsColor: NSColor.systemRed)
    static let successGreen = Color(nsColor: NSColor.systemGreen)
}
```

**文件：`JSONMaster/JSONMaster/Extensions/String+JSON.swift`**

```swift
import Foundation

extension String {
    var isValidJSON: Bool {
        JSONFormatterService.validate(self)
    }

    var prettyJSON: String? {
        switch JSONFormatterService.format(self, style: .pretty) {
        case .success(let result): return result
        case .failure: return nil
        }
    }

    var compactJSON: String? {
        switch JSONFormatterService.format(self, style: .compact) {
        case .success(let result): return result
        case .failure: return nil
        }
    }

    var jsonByteSize: String {
        let bytes = self.utf8.count
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    /// Extract a short title from JSON content for sidebar display
    var jsonTitle: String {
        guard let data = self.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return "Invalid JSON"
        }
        if let dict = obj as? [String: Any] {
            // Use first key as hint
            if let firstKey = dict.keys.sorted().first {
                return "{ \"\(firstKey)\" ... } (\(dict.count) keys)"
            }
            return "{ } (empty)"
        }
        if let arr = obj as? [Any] {
            return "[ ... ] (\(arr.count) items)"
        }
        return "JSON Value"
    }
}
```

---

### Task 6：语法高亮编辑器组件（NSViewRepresentable）

**文件：`JSONMaster/JSONMaster/Views/Editor/JSONTextEditor.swift`**

```swift
import SwiftUI
import AppKit

struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var onTextChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = SyntaxHighlighter.currentTheme().background

        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        // Apply initial highlighting
        DispatchQueue.main.async {
            context.coordinator.applyHighlighting()
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting()
        }

        textView.backgroundColor = SyntaxHighlighter.currentTheme().background
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONTextEditor
        weak var textView: NSTextView?
        private var isUpdating = false

        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = textView else { return }
            isUpdating = true
            parent.text = textView.string
            parent.onTextChange?(textView.string)
            applyHighlighting()
            isUpdating = false
        }

        func applyHighlighting() {
            guard let textView = textView else { return }
            let theme = SyntaxHighlighter.currentTheme()
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let highlighted = SyntaxHighlighter.highlight(
                textView.string,
                theme: theme,
                font: font
            )

            let selectedRanges = textView.selectedRanges
            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributedString(highlighted)
            textView.textStorage?.endEditing()
            textView.selectedRanges = selectedRanges
        }
    }
}
```

---

### Task 7：侧边栏视图

**文件：`JSONMaster/JSONMaster/Views/Sidebar/HistoryRowView.swift`**

```swift
import SwiftUI

struct HistoryRowView: View {
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(item.title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(item.rawJSON.jsonByteSize)
                    .font(.caption)
                    .foregroundStyle(.subtleText)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.subtleText)

                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.subtleText)
            }
        }
        .padding(.vertical, 4)
    }
}
```

**文件：`JSONMaster/JSONMaster/Views/Sidebar/SidebarView.swift`**



好的，以下是剩余任务的精简规划，只描述每个文件的**职责、关键接口和实现要点**，不再输出完整代码。

---

### Task 7（续）：侧边栏视图

**`SidebarView.swift`** — 补全剩余部分：

* `unpinnedItems` 区域用 `Section("History")` 展示
* 每个 item 的 `contextMenu` 提供：Pin/Unpin、Rename、Copy JSON、Delete
* 底部工具栏放一个 `+` 按钮（新建空白 JSON）和一个清空历史按钮
* `searchText` 绑定到 `.searchable(text:)` 修饰符
* 删除操作调用 `modelContext.delete(item)`

---

### Task 8：编辑器容器视图

**`JSONMaster/JSONMaster/Views/Editor/EditorContainerView.swift`**

职责：编辑区的整体容器，包含工具栏 + 编辑器 + 状态栏。

* **顶部工具栏**（HStack）：
  * 「Format」按钮 — 调用 `JSONFormatterService.format(.pretty)`
  * 「Compact」按钮 — 调用 `JSONFormatterService.minify()`
  * 「Copy」按钮 — 复制格式化结果到剪贴板 `NSPasteboard`
  * 「Clear」按钮 — 清空编辑区
  * 工具栏使用 SF Symbols 图标 + `.buttonStyle(.borderless)`
* **中间区域**：放置 `JSONTextEditor`（Task 6 的组件），绑定 `@State var editorText`
* **底部**：放置 `StatusBarView`
* 当用户粘贴或输入文本后，自动调用 `JSONFormatterService.validate()` 更新状态
* 如果 `selectedItem` 从侧边栏传入，则加载其 `rawJSON` 到编辑器

---

### Task 9：状态栏视图

**`JSONMaster/JSONMaster/Views/Editor/StatusBarView.swift`**

职责：编辑器底部的信息条。

* 左侧显示：JSON 类型（Object/Array）、key/元素数量、字节大小
* 右侧显示：校验状态（✓ Valid / ✗ Invalid），用绿色/红色圆点指示
* 使用 `HStack` + `Spacer()` 布局
* 字体 `.caption`，颜色 `.secondary`
* 接收参数：`isValid: Bool`、`jsonType: String`、`byteSize: String`、`keyCount: Int`

---

### Task 10：主布局视图

**`JSONMaster/JSONMaster/Views/ContentView.swift`**

职责：组装整个窗口布局。

* 使用 `NavigationSplitView` 实现左右分栏
* 左栏：`SidebarView(selectedItem: $selectedItem)`，列宽约束 `min: 200, ideal: 240, max: 320`
* 右栏（detail）：`EditorContainerView(selectedItem: $selectedItem)`
* 当 `selectedItem == nil` 时，detail 区域显示空状态占位（图标 + "Paste JSON or create new" 提示文字）
* 添加键盘快捷键：
  * `⌘+N` — 新建 JSON 条目
  * `⌘+V` — 粘贴并自动格式化（通过 `.onCommand` 或 menu commands）
* 添加 `.onDrop(of: [.fileURL])` 支持拖入 `.json` 文件
* 窗口最小尺寸 `.frame(minWidth: 800, minHeight: 500)`

---

### Task 11：菜单栏命令

**`JSONMaster/JSONMaster/App/JSONMasterApp.swift`** — 扩展 `commands`：

* 在 `body` 的 `WindowGroup` 后追加 `.commands { ... }`
* **File 菜单**：
  * `New JSON` (⌘+N) — 创建空白条目并选中
  * `Open JSON File` (⌘+O) — 弹出 `NSOpenPanel`，过滤 `.json` 文件
  * `Save` (⌘+S) — 将当前编辑内容保存到 `HistoryItem`
  * `Export` (⌘+Shift+S) — `NSSavePanel` 导出为 `.json` 文件
* **Edit 菜单**：
  * `Format JSON` (⌘+B) — 美化
  * `Compact JSON` (⌘+Shift+B) — 压缩
* 使用 `CommandGroup(replacing:)` 和 `CommandGroup(after:)` 插入

---

### Task 12：Xcode 项目配置

由于 Codex 环境无法运行 Xcode GUI，需要手动生成 `project.pbxproj`。

**推荐替代方案**：使用 Swift Package 可执行方式，或者提供一个 `generate_project.sh` 脚本：

```bash
#!/bin/bash
# 使用 xcodegen 或手动创建 project.pbxproj
# 方案 A：提供 project.yml 给 XcodeGen
# 方案 B：提供完整的 .pbxproj 文件
```

**`project.yml`**（XcodeGen 格式）：

```yaml
name: JSONMaster
options:
  bundleIdPrefix: com.jsonmaster
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

targets:
  JSONMaster:
    type: application
    platform: macOS
    sources:
      - JSONMaster
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jsonmaster.app
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: 1
        SWIFT_VERSION: "5.9"
        MACOSX_DEPLOYMENT_TARGET: "14.0"
        INFOPLIST_KEY_LSApplicationCategoryType: "public.app-category.developer-tools"
        INFOPLIST_KEY_CFBundleDisplayName: "JSON Master"
        ENABLE_HARDENED_RUNTIME: YES
        CODE_SIGN_ENTITLEMENTS: ""
        PRODUCT_NAME: "JSON Master"
```

构建命令：

```bash
# 安装 xcodegen（如未安装）
brew install xcodegen

# 生成 Xcode 项目
cd JSONMaster
xcodegen generate

# 构建
xcodebuild -project JSONMaster.xcodeproj \
  -scheme JSONMaster \
  -configuration Release \
  -derivedDataPath build \
  build
```

---

### Task 13：README

**`JSONMaster/README.md`**

内容要点：

* 项目简介：原生 macOS JSON 格式化/编辑器
* 功能列表：格式化、压缩、语法高亮、历史记录、拖拽文件、暗色模式
* 技术栈：Swift 5.9 / SwiftUI / SwiftData / 零第三方依赖
* 构建说明：依赖 XcodeGen，给出 3 步构建命令
* 系统要求：macOS 14.0+
* 后续规划路线图：JSONPath 支持 → JS 脚本引擎 → 树形视图 → 对比 Diff

---

## 任务执行顺序总结

| 顺序 | 任务 | 产出文件 | 依赖 |
|:---|:---|:---|:---|
| 1 | 项目骨架 + 资源 | `JSONMasterApp.swift`、Assets | 无 |
| 2 | 数据模型 | `HistoryItem.swift`、`JSONDocument.swift` | 无 |
| 3 | JSON 格式化服务 | `JSONFormatterService.swift` | 无 |
| 4 | 语法高亮引擎 | `SyntaxHighlighter.swift` | 无 |
| 5 | 扩展工具 | `Color+Theme.swift`、`String+JSON.swift` | Task 3 |
| 6 | 编辑器组件 | `JSONTextEditor.swift` | Task 4 |
| 7 | 侧边栏视图 | `SidebarView.swift`、`HistoryRowView.swift` | Task 2, 5 |
| 8 | 编辑器容器 | `EditorContainerView.swift` | Task 3, 6 |
| 9 | 状态栏 | `StatusBarView.swift` | 无 |
| 10 | 主布局 | `ContentView.swift` | Task 7, 8, 9 |
| 11 | 菜单命令 | 修改 `JSONMasterApp.swift` | Task 10 |
| 12 | 项目配置 | `project.yml` + 构建脚本 | 全部 |
| 13 | 文档 | `README.md` | 全部 |

---





