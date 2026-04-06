import AppKit
import SwiftUI

struct EditorContainerView: View {
    @Binding var selectedItem: HistoryItem?
    @Binding var editorText: String

    @State private var isValid = false
    @State private var jsonType = JSONDocument.JSONType.unknown
    @State private var keyCount = 0
    @State private var validationIssue: JSONValidationIssue?
    @State private var toastMessage: String?
    @State private var toastDismissTask: DispatchWorkItem?
    @State private var errorRevealToken = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            JSONTextEditor(
                text: $editorText,
                errorHighlight: currentErrorHighlight,
                errorRevealToken: errorRevealToken
            )
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
