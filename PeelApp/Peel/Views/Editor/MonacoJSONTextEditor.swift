import AppKit
import SwiftUI
import WebKit

@MainActor
protocol MonacoEditorCommandHandling: AnyObject {
    func focusEditor()
    func copySelectionOrAll()
    func cutSelection()
    func paste(_ string: String)
    func selectAll()
    func showFind()
}

@MainActor
final class MonacoEditorCommandCenter {
    static let shared = MonacoEditorCommandCenter()

    private weak var focusedEditor: MonacoEditorCommandHandling?

    private init() {}

    func registerFocusedEditor(_ editor: MonacoEditorCommandHandling) {
        focusedEditor = editor
    }

    func unregisterFocusedEditor(_ editor: MonacoEditorCommandHandling) {
        guard focusedEditor === editor else {
            return
        }

        focusedEditor = nil
    }

    @discardableResult
    func performCopy() -> Bool {
        guard let focusedEditor else {
            return false
        }

        focusedEditor.copySelectionOrAll()
        return true
    }

    @discardableResult
    func performCut() -> Bool {
        guard let focusedEditor else {
            return false
        }

        focusedEditor.cutSelection()
        return true
    }

    @discardableResult
    func performPaste(_ string: String) -> Bool {
        guard let focusedEditor else {
            return false
        }

        focusedEditor.paste(string)
        return true
    }

    @discardableResult
    func performSelectAll() -> Bool {
        guard let focusedEditor else {
            return false
        }

        focusedEditor.selectAll()
        return true
    }

    @discardableResult
    func performFind() -> Bool {
        guard let focusedEditor else {
            return false
        }

        focusedEditor.showFind()
        return true
    }
}

struct MonacoJSONTextEditor: NSViewRepresentable {
    @Environment(EditorLayoutSettings.self) private var editorLayoutSettings
    @Environment(\.colorScheme) private var colorScheme
    let role: MonacoEditorPool.Role
    @Binding var text: String
    var isEditable: Bool = true
    var language: String = "json"
    var fontSize: Int = Int(EditorLayoutSettings.defaultFontSize)
    var placeholder: String? = nil
    var errorHighlight: EditorErrorHighlight?
    var errorRevealToken: Int = 0
    var focusRequestToken: Int = 0
    var onEditingEnded: (() -> Void)?
    var onTextChange: ((String) -> Void)?
    var onRun: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, pooledEditor: MonacoEditorPool.shared.editor(for: role))
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = context.coordinator.pooledEditor.webView
        webView.removeFromSuperview()
        context.coordinator.attach()
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyStateIfNeeded()
        context.coordinator.applyFocusRequestIfNeeded(focusRequestToken)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
        MonacoEditorCommandCenter.shared.unregisterFocusedEditor(coordinator)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, MonacoEditorCommandHandling {
        var parent: MonacoJSONTextEditor
        let pooledEditor: PooledEditor

        private var isEditorReady = false
        private var lastHandledFocusRequest = 0

        private static let messageHandlerName = "peelEditor"

        init(parent: MonacoJSONTextEditor, pooledEditor: PooledEditor) {
            self.parent = parent
            self.pooledEditor = pooledEditor
        }

        func attach() {
            pooledEditor.webView.navigationDelegate = self
            pooledEditor.setMessageHandler { [weak self] message in
                self?.handleMessage(message)
            }

            if pooledEditor.isReady {
                isEditorReady = true
                applyStateIfNeeded(force: true)
            }

            pooledEditor.loadPage()
        }

        func detach() {
            if pooledEditor.webView.navigationDelegate === self {
                pooledEditor.webView.navigationDelegate = nil
            }
        }

        // MARK: - State

        func applyStateIfNeeded(force: Bool = false) {
            guard isEditorReady else { return }

            let payload = MonacoEditorStatePayload(
                text: parent.text,
                isEditable: parent.isEditable,
                language: parent.language,
                fontSize: parent.fontSize,
                placeholder: parent.placeholder,
                errorHighlight: MonacoErrorHighlightPayload(parent.errorHighlight),
                errorRevealToken: parent.errorRevealToken,
                theme: MonacoThemePayload(
                    theme: SyntaxHighlighter.currentTheme(for: parent.colorScheme)
                )
            )

            guard let data = try? JSONEncoder().encode(payload),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return
            }

            guard force || jsonString != pooledEditor.lastAppliedStateSignature else {
                return
            }

            pooledEditor.recordAppliedState(signature: jsonString)
            pooledEditor.webView.evaluateJavaScript("window.PeelMonaco?.applyState(\(jsonString));")
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pooledEditor.markPageLoaded()
        }

        // MARK: - Message Handling

        private func handleMessage(_ message: WKScriptMessage) {
            guard message.name == Self.messageHandlerName,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }

            switch type {
            case "ready":
                isEditorReady = true
                pooledEditor.markReady()
                applyStateIfNeeded(force: true)
            case "change":
                guard let text = body["text"] as? String else {
                    return
                }

                if parent.text != text {
                    parent.text = text
                }
                parent.onTextChange?(text)
            case "focus":
                MonacoEditorCommandCenter.shared.registerFocusedEditor(self)
            case "blur":
                MonacoEditorCommandCenter.shared.unregisterFocusedEditor(self)
                parent.onEditingEnded?()
            case "run":
                parent.onRun?()
            default:
                break
            }
        }

        // MARK: - Commands

        func focusEditor() {
            let webView = pooledEditor.webView
            webView.window?.makeFirstResponder(webView)
            webView.evaluateJavaScript("window.PeelMonaco?.focus();")
        }

        func copySelectionOrAll() {
            focusEditor()
            pooledEditor.webView.evaluateJavaScript("window.PeelMonaco?.copySelectionOrAll();") { result, _ in
                guard let string = result as? String else {
                    return
                }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        }

        func cutSelection() {
            focusEditor()
            pooledEditor.webView.evaluateJavaScript("window.PeelMonaco?.cutSelection();") { result, _ in
                guard let string = result as? String,
                      !string.isEmpty else {
                    return
                }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        }

        func paste(_ string: String) {
            focusEditor()
            guard let encodedString = string.javascriptStringLiteral else {
                return
            }

            pooledEditor.webView.evaluateJavaScript("window.PeelMonaco?.pasteText(\(encodedString));")
        }

        func selectAll() {
            focusEditor()
            pooledEditor.webView.evaluateJavaScript("window.PeelMonaco?.selectAll();")
        }

        func showFind() {
            focusEditor()
            pooledEditor.webView.evaluateJavaScript("window.PeelMonaco?.showFind();")
        }

        func applyFocusRequestIfNeeded(_ token: Int) {
            guard token > 0, token != lastHandledFocusRequest else { return }
            lastHandledFocusRequest = token
            DispatchQueue.main.async { [weak self] in
                self?.focusEditor()
            }
        }
    }
}

private struct MonacoEditorStatePayload: Encodable {
    let text: String
    let isEditable: Bool
    let language: String
    let fontSize: Int
    let placeholder: String?
    let errorHighlight: MonacoErrorHighlightPayload?
    let errorRevealToken: Int
    let theme: MonacoThemePayload
}

private struct MonacoErrorHighlightPayload: Encodable {
    let tokenStart: Int
    let tokenEnd: Int
    let lineStart: Int
    let lineEnd: Int
    let message: String

    init?(_ highlight: EditorErrorHighlight?) {
        guard let highlight else {
            return nil
        }

        tokenStart = highlight.tokenRange.location
        tokenEnd = max(highlight.tokenRange.location + highlight.tokenRange.length, highlight.tokenRange.location + 1)
        lineStart = highlight.lineRange.location
        lineEnd = max(highlight.lineRange.location + highlight.lineRange.length - 1, highlight.lineRange.location)
        message = highlight.message
    }
}

private struct MonacoThemePayload: Encodable {
    let variant: String
    let background: String
    let defaultText: String
    let key: String
    let string: String
    let number: String
    let boolean: String
    let nullColor: String
    let brace: String
    let lineNumber: String
    let cursor: String
    let selectionBackground: String
    let inactiveSelectionBackground: String
    let indentGuide: String
    let scrollbar: String
    let errorLineBackground: String
    let errorTokenBackground: String
    let errorBorder: String

    init(theme: SyntaxHighlighter.Theme) {
        let appearance = theme.appearance

        variant = theme.variant == .dark ? "dark" : "light"
        background = theme.background.hexRGBA
        defaultText = theme.defaultText.hexRGBA
        key = theme.key.hexRGBA
        string = theme.string.hexRGBA
        number = theme.number.hexRGBA
        boolean = theme.boolean.hexRGBA
        nullColor = theme.null.hexRGBA
        brace = theme.brace.hexRGBA
        if theme.variant == .dark {
            lineNumber = NSColor.secondaryLabelColor
                .resolved(for: appearance)
                .withAlphaComponent(0.68)
                .hexRGBA
        } else {
            lineNumber = NSColor.secondaryLabelColor
                .resolved(for: appearance)
                .hexRGBA
        }
        cursor = theme.defaultText.hexRGBA
        selectionBackground = NSColor.selectedTextBackgroundColor
            .resolved(for: appearance)
            .withAlphaComponent(0.28)
            .hexRGBA
        inactiveSelectionBackground = NSColor.selectedTextBackgroundColor
            .resolved(for: appearance)
            .withAlphaComponent(0.16)
            .hexRGBA
        indentGuide = NSColor.separatorColor
            .resolved(for: appearance)
            .withAlphaComponent(0.26)
            .hexRGBA
        scrollbar = NSColor.tertiaryLabelColor
            .resolved(for: appearance)
            .withAlphaComponent(0.24)
            .hexRGBA
        errorLineBackground = NSColor.systemRed
            .resolved(for: appearance)
            .withAlphaComponent(0.06)
            .hexRGBA
        errorTokenBackground = NSColor.systemRed
            .resolved(for: appearance)
            .withAlphaComponent(0.14)
            .hexRGBA
        errorBorder = NSColor.systemRed.resolved(for: appearance).hexRGBA
    }
}

private extension NSColor {
    func resolved(for appearance: NSAppearance) -> NSColor {
        var resolvedColor = self
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = usingColorSpace(.deviceRGB) ?? self
        }
        return resolvedColor
    }

    var hexRGBA: String {
        guard let color = usingColorSpace(.deviceRGB) else {
            return "#000000FF"
        }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        let alpha = Int(round(color.alphaComponent * 255))
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }
}

private extension String {
    var javascriptStringLiteral: String? {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}
