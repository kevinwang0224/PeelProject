# Monaco Editor 触控板轻点导致异常文本选中

## 问题描述

**环境**：macOS + WKWebView 内嵌 Monaco Editor，触控板开启"轻点来轻按"。

**复现步骤**：

1. 在编辑区轻点（tap）定位光标
2. 随后手指在触控板上滑动
3. 大概率出现：滑过的文字被选中（蓝色高亮）

**变体**：双击选中单词后，手指滑动会导致选区异常扩展。

**期望行为**：轻点后的滑动应该只是移动光标或什么都不做，而不是触发拖拽选中。

## 技术背景

### macOS 触控板 "轻点来轻按" 的事件特征（诊断修正）

此前假设轻点来轻按产生的事件与物理按下完全一致（`buttons=1`），但**通过注入诊断代码实际测量后，发现事实不同**：

| 操作方式 | `pointerdown.buttons` | `mousemove.buttons` | `pointerup` 触发时机 |
|---------|----------------------|---------------------|---------------------|
| 物理按下拖拽 | `1` | `1` | 手指抬起时 |
| **轻点来轻按** | **`0`** | **`0`** | **延迟或不触发** |

关键区别：轻点来轻按时，**所有事件的 `buttons` 始终为 `0`**（没有物理按钮被按下），且 `pointerup` 可能在手指完全离开触控板前不会触发。

### Monaco Editor 的拖拽选中实现

通过阅读 Monaco 打包源码（`editor.api-CalNCsUg.js`），确认其内部的拖拽选中链路为：

1. `pointerdown` 触发 → Monaco 的 mousedown handler 处理光标定位
2. 调用 `GlobalPointerMoveMonitor.startMonitoring(element, pointerId, buttons, callback)`
3. 内部调用 `element.setPointerCapture(pointerId)` 捕获指针
4. 监听 `pointermove` 事件 → 通过 callback 更新选区
5. 当 `pointermove.buttons !== initialButtons` 时调用 `stopMonitoring()` 结束
6. `pointerup` 或 `lostpointercapture` 触发 → `stopMonitoring()` 结束

关键点：
- `setPointerCapture` 会把所有后续 pointer 事件**直接路由到捕获元素上**，绕过正常的 DOM 事件冒泡路径。
- Monaco 用 `pointermove.buttons !== initialButtons` 检测拖拽结束。如果 `initialButtons=0`（轻点来轻按），后续 `pointermove.buttons` 也是 `0`，条件 `0 !== 0` **永远不成立**，Monaco 永远不会自动停止拖拽监听。

### 现有代码中的防护措施

`monaco-editor.html` 中已有三层防护：

1. **CSS `user-select: none`**：在 `html, body, #editor` 上设置，防止浏览器原生选区
2. `**suppressNativeTrackpadSelection()**`：拦截 `selectstart`、`dragstart`、`selectionchange` 事件
3. `**installMouseInteractionGuard()**`：在 `document` capture 阶段拦截 `pointermove/mousemove`，有 4px 移动阈值防抖

## 已尝试但无效的方案

### 方案 1：禁用 `window.PointerEvent`

```javascript
// 尝试在 Monaco 加载前删除 PointerEvent 全局对象
delete window.PointerEvent;
Object.defineProperty(window, "PointerEvent", { get: () => undefined });
```

**思路**：欺骗 Monaco 不使用 PointerEvent，降级到 MouseEvent。

**无效原因**：WebKit 不管 `window.PointerEvent` 是否存在，浏览器底层仍然会发出 `pointerdown/pointermove/pointerup` 事件。Monaco 监听的是 DOM 事件类型字符串 `"pointermove"` 而非检查 `window.PointerEvent` 构造函数。

### 方案 2：在 `mousemove` 中检测 `event.buttons === 0` 后派发伪造 `mouseup`

```javascript
if ((event.buttons & 1) === 0) {
    document.dispatchEvent(new MouseEvent("mouseup", { ... }));
}
```

**思路**：如果 `buttons=0` 说明手指已松开，WebKit 漏掉了 mouseup，手动补发。

**无效原因**：

1. 在"轻点来轻按"场景下，系统把手势解释为 click-drag，`buttons` 确实是 `1`（系统认为按钮处于按下状态），不是漏掉了 mouseup
2. Monaco 使用的是 `pointerup` 而非 `mouseup`，伪造的 `mouseup` 事件 Monaco 不处理
3. 即使伪造 `pointerup`，由于 `isTrusted=false`，Monaco 可能忽略

### 方案 3：将事件拦截器从 `document` 提升到 `window` + 120ms 时间窗口

```javascript
// 在 window capture 阶段拦截
window.addEventListener("pointermove", handleMove, true);

// 如果 mousedown 后 120ms 内出现超过 4px 的移动 → 判定为轻点后滑动
if (elapsed < TAP_GRACE_MS) {
    cancelAndCollapse();
    event.stopImmediatePropagation();
}
```

**思路**：利用 DOM 事件传播顺序（window capture 最先执行），在 Monaco 之前拦截事件；并通过时间判定来区分"轻点后滑动"和"按住拖拽"。

**无效原因**：Monaco 使用 `setPointerCapture(pointerId)` 后，被捕获的 pointer 事件的传播路径与正常事件不同。尽管 W3C 规范说捕获的事件仍经过 capture 阶段，但 WebKit 的实际实现中 `stopImmediatePropagation` 可能无法阻止已被 capture 的事件到达目标元素。另外即使在 `installMouseInteractionGuard()` 之后才创建 Monaco editor（理论上我们的 handler 先注册），但 Monaco 的 `startMonitoring` 是在每次 mousedown 时动态注册的，注册时机和事件路由受 `setPointerCapture` 影响。

### 方案 4：Monaco API 层面的 `onDidChangeCursorSelection` 守卫

```javascript
editor.onMouseDown(() => {
    // 在 mousedown 处理完成后快照选区
    Promise.resolve().then(() => { baseSelection = editor.getSelection(); });
});

editor.onDidChangeCursorSelection(() => {
    // 150ms 内选区偏离快照 → 恢复
    if (elapsed < 150 && !current.equalsSelection(baseSelection)) {
        editor.setSelection(baseSelection);
    }
});
```

**思路**：不在事件层面拦截，而是监听选区变化结果，一旦检测到异常就还原。

**无效原因**：待确认。可能的问题包括：

- `onMouseDown` 和 `onDidChangeCursorSelection` 的触发时序与预期不符
- Monaco 的 `setSelection` 调用是否能真正覆盖正在进行中的拖拽选中状态
- 可能看到的"选中"实际上是**浏览器原生文本选区**而非 Monaco 内部选区

### 方案 5：CSS 强制 Monaco 内部元素 `user-select: none`

```css
.monaco-editor .lines-content,
.monaco-editor .view-lines,
.monaco-editor .view-line > span {
    -webkit-user-select: none !important;
    user-select: none !important;
}
```

**思路**：Monaco 的内部 CSS 可能在子元素上设置了 `user-select: text`，覆盖了父级的 `none`。

**无效原因**：与方案 4 一起应用后仍然无效。如果问题确实是 Monaco 内部选区（而非浏览器原生选区），这个 CSS 修改不会有任何影响。

## 诊断过程

在方案 1–5 均失败后，注入了全量诊断代码（`installSelectionDiagnostics()`），在编辑器底部叠加一个实时日志面板，记录所有 pointer/mouse 事件、Monaco 选区变化和浏览器原生选区变化。同时在 DEBUG 构建中开启 `WKWebView.isInspectable` 以支持 Safari Web Inspector。

### 诊断关键发现

复现问题时的事件序列（从诊断面板截取）：

```
111228ms pointerdown buttons=0 btn=0 detail=1 pid=1 trusted=true +0ms
111229ms mousedown   buttons=0 btn=0 detail=1 trusted=true +0ms
111231ms [MONACO SEL] empty=true  range=34:24-34:24 reason=3 source="mouse"  +2ms
111395ms [MONACO SEL] empty=false range=34:24-34:25 reason=3 source="mouse" text="心"  +166ms
111397ms [NATIVE SEL] text="心" rangeCount=1  +168ms
111461ms [MONACO SEL] empty=false range=34:24-35:25 ...  +233ms
111477ms mousemove(x12) buttons=0  +248ms
111579ms mousemove(x14) buttons=0  +350ms
  ... 选区持续扩展，mousemove 全程 buttons=0 ...
```

关键事实：

1. **`pointerdown.buttons=0` 和 `mousedown.buttons=0`** — 轻点来轻按时没有物理按钮被按下
2. **`[MONACO SEL]` 和 `[NATIVE SEL]` 同时出现** — 选中同时发生在 Monaco 和浏览器原生层
3. **`mousemove` 全程 `buttons=0`** — 但 Monaco 选区持续扩展
4. **没有 `pointerup`/`mouseup`** — 在可见的时间窗口内没有出现

### 根因确认

Monaco 的 `GlobalPointerMoveMonitor` 在 `pointerdown` 时记录 `initialButtons = 0`，然后在 `pointermove` 中检查 `e.buttons !== initialButtons` 来判断拖拽是否结束。由于 `pointermove.buttons` 也是 `0`，条件 `0 !== 0` 永远为 `false`，Monaco **永远不会自动停止拖拽监听**，导致手指在触控板上的任何移动都被解释为拖拽选中。

## 最终修复方案：`installPointerCaptureGuard()`

### 原理

利用 `pointerdown.buttons === 0` 作为 tap-to-click 的特征标识。检测到后，在 `window` capture 阶段拦截所有 `pointermove` 事件并释放 pointer capture，直到 `pointerup`/`mouseup` 触发。

### 实现

```javascript
function installPointerCaptureGuard() {
    let tapToClickActive = false;
    let safetyTimer = null;

    window.addEventListener("pointerdown", (e) => {
        if (safetyTimer) { clearTimeout(safetyTimer); safetyTimer = null; }
        if (e.button === 0 && e.isTrusted && e.buttons === 0) {
            tapToClickActive = true;
            safetyTimer = setTimeout(() => { tapToClickActive = false; }, 2000);
        } else {
            tapToClickActive = false;
        }
    }, true);

    for (const evt of ["pointerup", "mouseup"]) {
        window.addEventListener(evt, (e) => {
            if (e.button === 0) {
                tapToClickActive = false;
                if (safetyTimer) { clearTimeout(safetyTimer); safetyTimer = null; }
            }
        }, true);
    }

    window.addEventListener("pointermove", (e) => {
        if (tapToClickActive && e.isTrusted) {
            e.stopImmediatePropagation();
            e.preventDefault();
            try { e.target.releasePointerCapture(e.pointerId); } catch (_) {}
        }
    }, true);
}
```

### 关键设计

| 要素 | 说明 |
|------|------|
| 检测条件 | `pointerdown` 时 `button=0 && buttons=0`（仅 tap-to-click 会出现） |
| 拦截方式 | `window` capture 阶段 `stopImmediatePropagation()` — 在 Monaco 监听器之前执行 |
| Capture 释放 | `e.target.releasePointerCapture()` 触发 `lostpointercapture` → Monaco 调用 `stopMonitoring()` 干净退出 |
| 恢复时机 | `pointerup` 或 `mouseup` 清除标记 |
| 安全兜底 | 2 秒超时，防止 `pointerup` 丢失导致永久阻塞 |
| 注册时机 | `boot()` 中 Monaco 加载之前，确保 listener 注册顺序在 Monaco 之前 |

### 不影响的场景

- **物理按下拖拽选中**：`pointerdown.buttons=1`，不触发守卫
- **双击选词**：两次快速 pointerdown+pointerup，`tapToClickActive` 在 pointerup 时清除
- **右键菜单**：`button=2`，不触发守卫
- **滚动**：滚动产生 `wheel` 事件，不经过 `pointermove`
- **悬停效果**：`tapToClickActive` 仅在 tap-to-click 到 pointerup 之间生效

## 相关文件

- `PeelApp/Peel/Resources/Monaco/monaco-editor.html` — Monaco 编辑器 HTML 容器和所有 JS 逻辑
- `PeelApp/Peel/Views/Editor/MonacoEditorPool.swift` — WKWebView 创建和配置
- `PeelApp/Peel/Views/Editor/MonacoJSONTextEditor.swift` — Monaco 的 SwiftUI 封装
- `PeelApp/Peel/Resources/Monaco/vs/editor.api-CalNCsUg.js` — Monaco 打包源码（只读参考）

## 相关社区 Issues

- [microsoft/monaco-editor#925](https://github.com/microsoft/monaco-editor/issues/925) — Mouse events not working in AppleWebKit
- [microsoft/monaco-editor#2205](https://github.com/microsoft/monaco-editor/issues/2205) — Scroll/copy/paste/select all not working on WKWebview
- [microsoft/monaco-editor#2277](https://github.com/microsoft/monaco-editor/issues/2277) — Weird behaviour with mixed use of touch and mouse/trackpad
- [microsoft/monaco-editor#3858](https://github.com/microsoft/monaco-editor/issues/3858) — Mouse click and Selection not working properly in shadow dom

