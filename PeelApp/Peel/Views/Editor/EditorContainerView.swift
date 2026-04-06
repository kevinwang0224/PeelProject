import AppKit
import SwiftUI

struct EditorContainerView: View {
    @Environment(JSONWorkspace.self) private var workspace
    @Binding var selectedItem: HistoryItem?
    @Binding var editorText: String

    @State private var isValid = false
    @State private var jsonType = JSONDocument.JSONType.unknown
    @State private var keyCount = 0
    @State private var validationIssue: JSONValidationIssue?
    @State private var toastMessage: String?
    @State private var toastDismissTask: DispatchWorkItem?
    @State private var errorRevealToken = 0
    @State private var extractionMode: ExtractionMode = .javaScript
    @State private var extractionQuery = ""
    @State private var extractionResult = ExtractionRunResult.idle

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            VSplitView {
                rawJSONView
                    .frame(minHeight: 240, idealHeight: 320, maxHeight: .infinity)

                extractionResultView
                    .frame(minHeight: 160, idealHeight: 210, maxHeight: .infinity)

                extractionQueryView
                    .frame(minHeight: 150, idealHeight: 180, maxHeight: 260)
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
        .onChange(of: selectedItem?.id, initial: false) { _, _ in
            syncFromSelection()
        }
        .onChange(of: editorText, initial: true) { _, _ in
            refreshStatus()
            invalidateExtractionResult()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            toolbarButton("Format", systemImage: "text.alignleft") {
                handleFormat(.pretty)
            }

            toolbarButton("Compact", systemImage: "arrow.down.right.and.arrow.up.left") {
                handleFormat(.compact)
            }

            toolbarButton("Copy", systemImage: "doc.on.doc") {
                copyFormattedJSON()
            }

            toolbarButton("Clear", systemImage: "trash") {
                clearEditor()
            }

            Spacer()

            if let validationIssue {
                Text(validationIssue.displayMessage)
                    .font(.caption)
                    .foregroundStyle(Color.errorRed)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var rawJSONView: some View {
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
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            JSONTextEditor(
                text: $editorText,
                errorHighlight: currentErrorHighlight,
                errorRevealToken: errorRevealToken,
                onEditingEnded: {
                    workspace.deleteSelectedItemIfEditorEmpty()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.editorBackground)
    }

    private var extractionResultView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Extraction Result")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(resultStatusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(resultStatusColor)

                Button("Copy") {
                    copyExtractionResult()
                }
                .buttonStyle(.borderless)
                .disabled(!extractionResult.canCopy)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            JSONTextEditor(
                text: Binding(
                    get: { extractionResult.text },
                    set: { _ in }
                ),
                isEditable: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.editorBackground)
    }

    private var extractionQueryView: some View {
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

                Button(action: runExtraction) {
                    HStack(spacing: 6) {
                        Text("Run")
                        Text("⌘↩")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!canRunExtraction)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            ZStack(alignment: .topLeading) {
                ExpressionTextEditor(
                    text: $extractionQuery,
                    onRun: runExtraction
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
        .background(Color.editorBackground)
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
        editorText = selectedItem?.rawJSON ?? ""
        refreshStatus()
        extractionResult = .idle
    }

    private func refreshStatus() {
        let document = JSONDocument(raw: editorText)
        validationIssue = editorText.isEmpty ? nil : JSONFormatterService.validationIssue(editorText)
        isValid = !editorText.isEmpty && validationIssue == nil
        jsonType = document.type
        keyCount = document.keyCount
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
        guard validationIssue == nil else {
            extractionResult = ExtractionRunResult(
                status: .error,
                title: "Invalid JSON",
                text: "当前内容不是有效 JSON，不能执行提取。"
            )
            return
        }

        extractionResult = JSONExtractionService.run(
            input: editorText,
            query: extractionQuery,
            mode: extractionMode
        )
    }

    private func copyExtractionResult() {
        guard extractionResult.canCopy else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(extractionResult.text, forType: .string)
        showToast("Result Copied")
    }

    private func invalidateExtractionResult() {
        if extractionResult.status != .idle {
            extractionResult = .idle
        }
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
