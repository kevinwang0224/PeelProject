import AppKit
import SwiftUI

struct EditorContainerView: View {
    @Environment(JSONWorkspace.self) private var workspace
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    @Binding var selectedItem: HistoryItem?
    @Binding var editorText: String

    @State private var isValid = false
    @State private var jsonType = JSONDocument.JSONType.unknown
    @State private var keyCount = 0
    @State private var validationIssue: JSONValidationIssue?
    @State private var toastMessage: String?
    @State private var toastDismissTask: DispatchWorkItem?
    @State private var errorRevealToken = 0
    @State private var titleDraft = ""
    @State private var titleDraftItem: HistoryItem?
    @State private var extractionMode: ExtractionMode = .javaScript
    @State private var extractionQuery = ""
    @State private var extractionResult = ExtractionRunResult.idle
    @State private var preparedExtractionInput: JSONExtractionService.PreparedInput?
    @State private var isResultCollapsed = true
    @State private var shouldAutoExpandResultAfterNextRefresh = false
    @State private var isExpressionEditorCollapsed = false
    @State private var expressionEditorFocusRequest = 0
    @State private var extractionRefreshTask: DispatchWorkItem?
    @State private var latestExtractionRequestID: UInt64 = 0
    @FocusState private var isTitleFieldFocused: Bool

    private let collapsedPanelHeight: CGFloat = 44
    private let collapsedResultRailWidth: CGFloat = 36
    private let javaScriptAutoRefreshDelay: TimeInterval = 0.25
    private let jsonPathAutoRefreshDelay: TimeInterval = 0.25
    private let panelHeaderHeight: CGFloat = 38
    private static let extractionQueue = DispatchQueue(
        label: "Peel.EditorExtractionPreview",
        qos: .userInitiated
    )

    var body: some View {
        VStack(spacing: 0) {

            VSplitView {
                topContentView
                    .frame(minHeight: 260, idealHeight: 420, maxHeight: .infinity)

                extractionQueryView
                    .frame(
                        minHeight: isExpressionEditorCollapsed ? collapsedPanelHeight : 150,
                        idealHeight: isExpressionEditorCollapsed ? collapsedPanelHeight : 180,
                        maxHeight: isExpressionEditorCollapsed ? collapsedPanelHeight : 260
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            StatusBarView(
                isValid: isValid,
                jsonType: jsonType.rawValue,
                byteSize: editorText.jsonByteSize,
                keyCount: keyCount
            )
        }
        .background(Color.editorBackground)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                ControlGroup {
                    titleToolbarField
                }
            }
            
            
            
            // 右侧：操作按钮组
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                
                // 使用 ControlGroup 可以让一组相关的工具按钮更美观
                ControlGroup {
                    Button(action: { handleFormat(.pretty) }) {
                        Label("Format", systemImage: "text.alignleft")
                    }
                    
                    Button(action: { handleFormat(.compact) }) {
                        Label("Compact", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    
                    Button(action: { copyFormattedJSON() }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: { clearEditor() }) {
                        Label("Clear", systemImage: "trash")
                    }
                }
                .labelStyle(.titleAndIcon) // 如果你希望强制显示文字，添加此行
            }
            
        }
        .overlay(alignment: .topTrailing) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .padding(.top, 14)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            syncFromSelection()
        }
        .onDisappear {
            commitTitleDraft()
            cancelPendingExtractionRefresh()
            toastDismissTask?.cancel()
        }
        .onChange(of: selectedItem?.id, initial: false) { _, _ in
            commitTitleDraft()
            syncFromSelection()
        }
        .onChange(of: selectedItem?.title, initial: false) { _, newValue in
            guard !isTitleFieldFocused else {
                return
            }

            let nextTitle = newValue ?? ""
            if titleDraft != nextTitle {
                titleDraft = nextTitle
            }
        }
        .onChange(of: editorText, initial: true) { _, _ in
            refreshStatus()
            scheduleExtractionRefreshIfNeeded()
        }
        .onChange(of: extractionQuery, initial: false) { oldValue, newValue in
            handleExtractionQueryChange(from: oldValue, to: newValue)
            scheduleExtractionRefreshIfNeeded()
        }
        .onChange(of: extractionMode, initial: false) { _, _ in
            scheduleExtractionRefreshIfNeeded()
        }
        .onChange(of: isTitleFieldFocused, initial: false) { _, isFocused in
            if !isFocused {
                commitTitleDraft()
            }
        }
    }


    @ViewBuilder
    private var titleToolbarField: some View {
        if selectedItem != nil {
            TextField("JSON Title", text: $titleDraft)
                        .textFieldStyle(.plain) // 1. 改为 plain 样式，移除那个笨重的圆角黑框
                        .font(.system(size: 13, weight: .semibold)) // 2. 稍微加粗，模仿原生标题感
                        .foregroundStyle(.primary)
                        // 3. 核心：增加左侧间距
                        .padding(.leading, 12)
                        // 4. 固定宽度，防止标题过长挤压右侧按钮
                        .frame(minWidth: 180, maxWidth: 320)
                        .focused($isTitleFieldFocused)
                        .onSubmit(commitTitleDraft)
            
        }
    }

    @ViewBuilder
    private var topContentView: some View {
        if shouldShowExtractionResult {
            switch editorLayoutSettings.resultLayout {
            case .stacked:
                VSplitView {
                    rawJSONView
                        .frame(minHeight: 220, idealHeight: 320, maxHeight: .infinity)

                    extractionResultView
                        .frame(
                            minHeight: isResultCollapsed ? collapsedPanelHeight : 160,
                            idealHeight: isResultCollapsed ? collapsedPanelHeight : 210,
                            maxHeight: isResultCollapsed ? collapsedPanelHeight : .infinity
                        )
                }
            case .sideBySide:
                HSplitView {
                    rawJSONView
                        .frame(minWidth: 320, idealWidth: 500, maxWidth: .infinity)

                    if isResultCollapsed {
                        sideBySideCollapsedResultRail
                            .frame(
                                minWidth: collapsedResultRailWidth,
                                idealWidth: collapsedResultRailWidth,
                                maxWidth: collapsedResultRailWidth
                            )
                    } else {
                        extractionResultView
                            .frame(minWidth: 280, idealWidth: 360, maxWidth: .infinity)
                    }
                }
            }
        } else {
            rawJSONView
        }
    }

    private var rawJSONView: some View {
        RawJSONEditorPanel(
            editorText: $editorText,
            validationIssue: validationIssue,
            errorHighlight: currentErrorHighlight,
            errorRevealToken: errorRevealToken,
            panelHeaderHeight: panelHeaderHeight,
            onEditingEnded: {
                workspace.deleteSelectedItemIfEditorEmpty()
            }
        )
    }

    private var extractionResultView: some View {
        ExtractionResultPanel(
            result: extractionResult,
            isCollapsed: $isResultCollapsed,
            statusText: resultStatusText,
            statusColor: resultStatusColor,
            panelHeaderHeight: panelHeaderHeight,
            collapseSymbolName: resultCollapseSymbolName,
            collapseHelpText: resultCollapseHelpText,
            onCopy: copyExtractionResult
        )
    }

    private var sideBySideCollapsedResultRail: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isResultCollapsed = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("展开结果区")
            .padding(.top, 10)

            Spacer()

            Text("Result")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(90))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.bar)
    }

    private var resultCollapseSymbolName: String {
        switch editorLayoutSettings.resultLayout {
        case .sideBySide:
            return "chevron.right"
        case .stacked:
            return isResultCollapsed ? "chevron.down" : "chevron.up"
        }
    }

    private var resultCollapseHelpText: String {
        switch editorLayoutSettings.resultLayout {
        case .sideBySide:
            return "向右折叠结果区"
        case .stacked:
            return isResultCollapsed ? "展开结果区" : "折叠结果区"
        }
    }

    private var extractionQueryView: some View {
        ExpressionEditorPanel(
            extractionMode: $extractionMode,
            extractionQuery: $extractionQuery,
            isCollapsed: $isExpressionEditorCollapsed,
            canRunExtraction: canRunExtraction,
            extractionHint: extractionHint,
            extractionHintColor: extractionHintColor,
            focusRequestToken: expressionEditorFocusRequest,
            panelHeaderHeight: panelHeaderHeight,
            onRun: runExtraction
        )
    }

    private func collapseButton(
        symbolName: String,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.caption.weight(.semibold))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(helpText)
    }

    private var hasExtractionQuery: Bool {
        !extractionQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowExtractionResult: Bool {
        hasExtractionQuery && (!isResultCollapsed || extractionResult.status != .idle)
    }

    private func toolbarButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.borderless)
    }

    private func syncFromSelection() {
        cancelPendingExtractionRefresh()
        titleDraftItem = selectedItem
        titleDraft = selectedItem?.title ?? ""
        editorText = selectedItem?.rawJSON ?? ""
        refreshStatus()
        if hasExtractionQuery {
            scheduleExtractionRefreshIfNeeded(immediate: true)
        } else {
            extractionResult = .idle
            isResultCollapsed = true
        }
    }

    private func commitTitleDraft() {
        guard let titleDraftItem else {
            return
        }

        workspace.rename(titleDraftItem, to: titleDraft)
        titleDraft = titleDraftItem.title
    }

    private func refreshStatus() {
        let document = JSONDocument(raw: editorText)
        validationIssue = editorText.isEmpty ? nil : JSONFormatterService.validationIssue(editorText)
        isValid = !editorText.isEmpty && validationIssue == nil
        jsonType = document.type
        keyCount = document.keyCount
        updatePreparedExtractionInput()
    }

    private var currentErrorHighlight: EditorErrorHighlight? {
        guard let validationIssue,
              let tokenRange = validationIssue.highlightRange(in: editorText),
              let lineRange = validationIssue.lineRange(in: editorText) else {
            return nil
        }

        return EditorErrorHighlight(
            tokenRange: tokenRange,
            lineRange: lineRange,
            lineNumber: validationIssue.line,
            message: validationIssue.displayMessage
        )
    }

    private func handleFormat(_ style: JSONFormatStyle) {
        guard !editorText.isEmpty else {
            refreshStatus()
            return
        }

        let result: Result<String, JSONError>
        switch style {
        case .compact:
            result = JSONFormatterService.minify(editorText)
        case .pretty, .sortedKeys:
            result = JSONFormatterService.format(editorText, style: style)
        }

        switch result {
        case .success(let output):
            editorText = output
            showToast(style == .compact ? "Compacted" : "Formatted")
        case .failure(let error):
            if validationIssue == nil {
                validationIssue = JSONValidationIssue(
                    message: error.localizedDescription,
                    line: 1,
                    column: 1,
                    utf16Index: 0
                )
            }
            errorRevealToken += 1
        }

        refreshStatus()
    }

    private func copyFormattedJSON() {
        let stringToCopy: String
        switch JSONFormatterService.format(editorText, style: .pretty) {
        case .success(let output):
            stringToCopy = output
        case .failure:
            stringToCopy = editorText
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(stringToCopy, forType: .string)
        showToast("Copied")
    }

    private func clearEditor() {
        editorText = ""
        refreshStatus()
        showToast("Cleared")
    }

    private var canRunExtraction: Bool {
        !editorText.isEmpty &&
            validationIssue == nil &&
            !extractionQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var extractionHint: String {
        if let validationIssue {
            return "当前内容不是有效 JSON：\(validationIssue.displayMessage)"
        }

        return extractionMode.helpText
    }

    private var extractionHintColor: Color {
        validationIssue == nil ? .secondary : Color.errorRed
    }

    private var resultStatusText: String {
        switch extractionResult.status {
        case .idle:
            return "Ready"
        case .success:
            return "Result"
        case .empty:
            return "No Result"
        case .error:
            return "Error"
        }
    }

    private var resultStatusColor: Color {
        switch extractionResult.status {
        case .idle:
            return .secondary
        case .success:
            return Color.successGreen
        case .empty:
            return .secondary
        case .error:
            return Color.errorRed
        }
    }

    private func runExtraction() {
        guard canRunExtraction else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            isResultCollapsed = false
        }

        scheduleExtractionRefreshIfNeeded(immediate: true)
    }

    private func scheduleExtractionRefreshIfNeeded(immediate: Bool = false) {
        guard hasExtractionQuery else {
            cancelPendingExtractionRefresh()
            extractionResult = .idle
            return
        }

        guard validationIssue == nil,
              let preparedExtractionInput else {
            cancelPendingExtractionRefresh()
            extractionResult = .idle
            return
        }

        let trimmedQuery = extractionQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            cancelPendingExtractionRefresh()
            extractionResult = .idle
            return
        }

        cancelPendingExtractionRefresh()

        let mode = extractionMode
        let requestID = nextExtractionRequestID()
        let workItem = DispatchWorkItem {
            EditorContainerView.extractionQueue.async {
                let result = JSONExtractionService.run(
                    preparedInput: preparedExtractionInput,
                    query: trimmedQuery,
                    mode: mode
                )

                DispatchQueue.main.async {
                    guard latestExtractionRequestID == requestID else {
                        return
                    }

                    extractionResult = result
                    if shouldAutoExpandResultAfterNextRefresh {
                        isResultCollapsed = false
                        shouldAutoExpandResultAfterNextRefresh = false
                        expressionEditorFocusRequest += 1
                    }
                    extractionRefreshTask = nil
                }
            }
        }

        extractionRefreshTask = workItem
        let delay = immediate ? 0 : autoRefreshDelay(for: mode)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func handleExtractionQueryChange(from oldValue: String, to newValue: String) {
        let oldIsEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let newIsEmpty = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if oldIsEmpty && !newIsEmpty {
            shouldAutoExpandResultAfterNextRefresh = true
            return
        } else if !oldIsEmpty && newIsEmpty {
            extractionResult = .idle
            isResultCollapsed = true
            shouldAutoExpandResultAfterNextRefresh = false
            expressionEditorFocusRequest += 1
        }
    }

    private func cancelPendingExtractionRefresh() {
        extractionRefreshTask?.cancel()
        extractionRefreshTask = nil
        latestExtractionRequestID &+= 1
    }

    private func updatePreparedExtractionInput() {
        guard !editorText.isEmpty,
              validationIssue == nil else {
            preparedExtractionInput = nil
            return
        }

        preparedExtractionInput = try? JSONExtractionService.prepare(input: editorText)
    }

    private func autoRefreshDelay(for mode: ExtractionMode) -> TimeInterval {
        switch mode {
        case .javaScript:
            return javaScriptAutoRefreshDelay
        case .jsonPath:
            return jsonPathAutoRefreshDelay
        }
    }

    private func nextExtractionRequestID() -> UInt64 {
        latestExtractionRequestID &+= 1
        return latestExtractionRequestID
    }

    private func copyExtractionResult() {
        guard extractionResult.canCopy else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(extractionResult.text, forType: .string)
        showToast("Result Copied")
    }

    private func showToast(_ message: String) {
        toastDismissTask?.cancel()
        withAnimation(.spring(duration: 0.28)) {
            toastMessage = message
        }

        let dismissTask = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                toastMessage = nil
            }
        }

        toastDismissTask = dismissTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: dismissTask)
    }
}

private struct RawJSONEditorPanel: View {
    @Binding var editorText: String
    let validationIssue: JSONValidationIssue?
    let errorHighlight: EditorErrorHighlight?
    let errorRevealToken: Int
    let panelHeaderHeight: CGFloat
    let onEditingEnded: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Original JSON")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let validationIssue {
                    Text(validationIssue.displayMessage)
                        .font(.caption)
                        .foregroundStyle(Color.errorRed)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: panelHeaderHeight)
            .background(.bar)

            Divider()

            JSONTextEditor(
                text: $editorText,
                errorHighlight: errorHighlight,
                errorRevealToken: errorRevealToken,
                onEditingEnded: onEditingEnded
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.editorBackground)
    }
}

private struct ExtractionResultPanel: View {
    let result: ExtractionRunResult
    @Binding var isCollapsed: Bool
    let statusText: String
    let statusColor: Color
    let panelHeaderHeight: CGFloat
    let collapseSymbolName: String
    let collapseHelpText: String
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Extraction Result")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)

                Button("Copy", action: onCopy)
                    .buttonStyle(.borderless)
                    .disabled(!result.canCopy)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: collapseSymbolName)
                        .font(.caption.weight(.semibold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(collapseHelpText)
            }
            .padding(.horizontal, 12)
            .frame(height: panelHeaderHeight)
            .background(.bar)

            if !isCollapsed {
                Divider()

                if result.usesStructuredEditor {
                    JSONTextEditor(
                        text: .constant(result.text),
                        isEditable: false
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(verbatim: result.text)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.editorBackground)
                }
            }
        }
        .background(Color.editorBackground)
    }
}

private struct ExpressionEditorPanel: View {
    @Binding var extractionMode: ExtractionMode
    @Binding var extractionQuery: String
    @Binding var isCollapsed: Bool
    let canRunExtraction: Bool
    let extractionHint: String
    let extractionHintColor: Color
    let focusRequestToken: Int
    let panelHeaderHeight: CGFloat
    let onRun: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Expression Editor")
                    .font(.subheadline.weight(.semibold))

                Picker("Mode", selection: $extractionMode) {
                    ForEach(ExtractionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Spacer()

                Button(action: onRun) {
                    HStack(spacing: 6) {
                        Text("Run")
                        Text("⌘↩")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!canRunExtraction)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.semibold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(isCollapsed ? "展开代码编辑区" : "折叠代码编辑区")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)

            if !isCollapsed {
                Divider()

                ZStack(alignment: .topLeading) {
                    ExpressionTextEditor(
                        text: $extractionQuery,
                        onRun: onRun,
                        focusRequestToken: focusRequestToken
                    )

                    if extractionQuery.isEmpty {
                        Text(extractionMode.placeholder)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.editorBackground)

                Divider()

                HStack {
                    Text(extractionHint)
                        .font(.caption)
                        .foregroundStyle(extractionHintColor)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .background(Color.editorBackground)
    }
}
