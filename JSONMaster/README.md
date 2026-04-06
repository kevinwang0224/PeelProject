# JSONMaster

一个原生 macOS JSON 格式化和编辑工具，只依赖 Apple 自带框架。

## 功能

- JSON 美化和压缩
- 语法高亮编辑
- 历史记录和置顶
- 拖拽导入 `.json` 文件
- 剪贴板粘贴后自动整理
- 深色模式适配

## 技术栈

- Swift 5.9+
- SwiftUI
- SwiftData
- Foundation JSONSerialization
- 零第三方依赖

## 系统要求

- macOS 14.0 或更高版本
- Xcode 15+（命令行构建建议使用较新版本）
- XcodeGen

## 构建

```bash
cd JSONMaster
brew install xcodegen
xcodegen generate
xcodebuild -project JSONMaster.xcodeproj -scheme JSONMaster -configuration Debug -derivedDataPath build build
```

也可以直接运行：

```bash
cd JSONMaster
./generate_project.sh
```

## 主要能力

- 左侧历史栏支持搜索、重命名、复制、删除和置顶
- 右侧编辑区支持格式化、压缩、复制、清空
- 底部状态栏显示类型、条目数、大小和校验结果
- 菜单支持新建、打开、保存、导出、格式化和压缩

## 后续计划

- JSONPath 查询
- 树形结构浏览
- Diff 对比
- 脚本处理能力
