import AppKit
import WebKit

@MainActor
final class MonacoEditorPool {
    enum Role: String, CaseIterable {
        case rawJSON
        case extractionResult
        case expressionEditor
    }

    static let shared = MonacoEditorPool()

    private var editors: [Role: PooledEditor] = [:]

    func editor(for role: Role) -> PooledEditor {
        if let existing = editors[role] {
            return existing
        }

        let editor = PooledEditor()
        editors[role] = editor
        editor.loadPage()
        return editor
    }

    func preloadAll() {
        for role in Role.allCases {
            _ = editor(for: role)
        }
    }
}

@MainActor
final class PooledEditor {
    private(set) var webView: WKWebView
    private let messageProxy = MonacoMessageProxy()

    private(set) var isReady = false
    private(set) var isPageLoading = false
    private(set) var lastAppliedStateSignature = ""

    init() {
        let contentController = WKUserContentController()
        contentController.add(messageProxy, name: "peelEditor")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
    }

    func loadPage() {
        guard !isPageLoading, !isReady else { return }

        guard let htmlURL = Bundle.main.url(
            forResource: "monaco-editor",
            withExtension: "html",
            subdirectory: "Monaco"
        ) else {
            webView.loadHTMLString(
                "<html><body style='font-family: -apple-system; padding: 16px;'>Monaco \u{8d44}\u{6e90}\u{52a0}\u{8f7d}\u{5931}\u{8d25}\u{3002}</body></html>",
                baseURL: nil
            )
            return
        }

        isPageLoading = true
        let accessURL = htmlURL.deletingLastPathComponent()
        webView.loadFileURL(htmlURL, allowingReadAccessTo: accessURL)
    }

    func markReady() {
        isReady = true
        isPageLoading = false
    }

    func markPageLoaded() {
        isPageLoading = false
    }

    func setMessageHandler(_ handler: @escaping (WKScriptMessage) -> Void) {
        messageProxy.handler = handler
    }

    func clearMessageHandler() {
        messageProxy.handler = nil
    }

    func recordAppliedState(signature: String) {
        lastAppliedStateSignature = signature
    }
}

final class MonacoMessageProxy: NSObject, WKScriptMessageHandler {
    var handler: ((WKScriptMessage) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        handler?(message)
    }
}
