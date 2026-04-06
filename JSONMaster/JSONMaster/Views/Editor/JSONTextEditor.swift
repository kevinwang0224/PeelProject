import AppKit
import SwiftUI

struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var onTextChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = JSONFormattingTextView()

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
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = SyntaxHighlighter.currentTheme().background
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.transformPastedString = { pasted in
            pasted.prettyJSON ?? pasted
        }
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        DispatchQueue.main.async {
            context.coordinator.setText(text)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else {
            return
        }

        textView.isEditable = isEditable
        textView.backgroundColor = SyntaxHighlighter.currentTheme().background

        if textView.string != text {
            context.coordinator.setText(text)
        } else {
            context.coordinator.applyHighlighting()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONTextEditor
        weak var textView: NSTextView?
        private var isUpdating = false

        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView else {
                return
            }

            isUpdating = true
            parent.text = textView.string
            parent.onTextChange?(textView.string)
            applyHighlighting()
            isUpdating = false
        }

        func setText(_ text: String) {
            guard let textView else {
                return
            }

            isUpdating = true
            let selectedRanges = textView.selectedRanges
            textView.string = text
            applyHighlighting()
            textView.selectedRanges = selectedRanges
            isUpdating = false
        }

        func applyHighlighting() {
            guard let textView else {
                return
            }

            let selectedRanges = textView.selectedRanges
            let theme = SyntaxHighlighter.currentTheme()
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let highlighted = SyntaxHighlighter.highlight(
                textView.string,
                theme: theme,
                font: font
            )

            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributedString(highlighted)
            textView.textStorage?.endEditing()
            textView.selectedRanges = selectedRanges
        }
    }
}

final class JSONFormattingTextView: NSTextView {
    var transformPastedString: ((String) -> String)?

    override func paste(_ sender: Any?) {
        guard let pastedString = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }

        let output = transformPastedString?(pastedString) ?? pastedString
        insertText(output, replacementRange: selectedRange())
    }
}
