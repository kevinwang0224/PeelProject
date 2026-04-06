import AppKit
import SwiftUI

struct EditorContainerView: View {
    @Binding var selectedItem: HistoryItem?
    @Binding var editorText: String

    @State private var isValid = false
    @State private var jsonType = JSONDocument.JSONType.unknown
    @State private var keyCount = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            JSONTextEditor(text: $editorText)
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
                applyFormat(.pretty)
            }

            toolbarButton("Compact", systemImage: "arrow.down.right.and.arrow.up.left") {
                applyFormat(.compact)
            }

            toolbarButton("Copy", systemImage: "doc.on.doc") {
                copyFormattedJSON()
            }

            toolbarButton("Clear", systemImage: "trash") {
                clearEditor()
            }

            Spacer()

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
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
        errorMessage = nil
        refreshStatus()
    }

    private func refreshStatus() {
        let document = JSONDocument(raw: editorText)
        isValid = editorText.isEmpty ? false : editorText.isValidJSON
        jsonType = document.type
        keyCount = document.keyCount
    }

    private func applyFormat(_ style: JSONFormatStyle) {
        guard !editorText.isEmpty else {
            errorMessage = nil
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
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
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
    }

    private func clearEditor() {
        editorText = ""
        errorMessage = nil
        refreshStatus()
    }
}
