import AppKit
import SwiftUI

struct EditorErrorHighlight: Equatable {
    let tokenRange: NSRange
    let lineRange: NSRange
    let lineNumber: Int
    let message: String
}

struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var errorHighlight: EditorErrorHighlight?
    var errorRevealToken: Int = 0
    var onEditingEnded: (() -> Void)?
    var onTextChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = JSONFormattingTextView(frame: .zero)

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
        textView.textColor = SyntaxHighlighter.currentTheme().defaultText
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = SyntaxHighlighter.currentTheme().background
        textView.drawsBackground = true
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
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
        scrollView.borderType = .noBorder

        context.coordinator.setText(text)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? JSONFormattingTextView else {
            return
        }

        context.coordinator.parent = self
        textView.isEditable = isEditable
        textView.backgroundColor = SyntaxHighlighter.currentTheme().background
        textView.textColor = SyntaxHighlighter.currentTheme().defaultText
        textView.drawsBackground = true

        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(
                width: max(nsView.contentSize.width, 1),
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        if textView.string != text {
            context.coordinator.setText(text)
        } else {
            context.coordinator.applyHighlighting()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONTextEditor
        weak var textView: JSONFormattingTextView?
        private var isUpdating = false
        private var lastRevealedErrorToken = -1

        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onEditingEnded?()
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
            let highlighted = NSMutableAttributedString(
                attributedString: SyntaxHighlighter.highlight(
                    textView.string,
                    theme: theme,
                    font: font
                )
            )

            if let errorHighlight = parent.errorHighlight {
                let lineRange = clamp(errorHighlight.lineRange, to: highlighted.length)
                let tokenRange = clamp(errorHighlight.tokenRange, to: highlighted.length)

                if lineRange.length > 0 {
                    highlighted.addAttribute(
                        .backgroundColor,
                        value: NSColor.systemRed.withAlphaComponent(0.06),
                        range: lineRange
                    )
                }

                if tokenRange.length > 0 {
                    highlighted.addAttributes(
                        [
                            .backgroundColor: NSColor.systemRed.withAlphaComponent(0.14),
                            .underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue,
                            .underlineColor: NSColor.systemRed
                        ],
                        range: tokenRange
                    )
                }
            }

            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributedString(highlighted)
            textView.textStorage?.endEditing()
            textView.textColor = theme.defaultText
            textView.selectedRanges = selectedRanges

            if parent.errorRevealToken != lastRevealedErrorToken,
               let errorHighlight = parent.errorHighlight {
                textView.scrollRangeToVisible(errorHighlight.tokenRange)
                lastRevealedErrorToken = parent.errorRevealToken
            }
        }

        private func clamp(_ range: NSRange, to length: Int) -> NSRange {
            guard length > 0 else {
                return NSRange(location: 0, length: 0)
            }

            let location = min(max(range.location, 0), length - 1)
            let upperBound = min(NSMaxRange(range), length)
            return NSRange(location: location, length: max(upperBound - location, 1))
        }
    }
}

struct ExpressionTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onRun: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ExpressionNSTextView(frame: .zero)

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = false
        textView.isIncrementalSearchingEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = SyntaxHighlighter.currentTheme().defaultText
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = SyntaxHighlighter.currentTheme().background
        textView.drawsBackground = true
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.onRun = context.coordinator.runShortcutPressed
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.setText(text)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? ExpressionNSTextView else {
            return
        }

        context.coordinator.parent = self
        textView.backgroundColor = SyntaxHighlighter.currentTheme().background
        textView.textColor = SyntaxHighlighter.currentTheme().defaultText
        textView.drawsBackground = true
        textView.onRun = context.coordinator.runShortcutPressed

        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(
                width: max(nsView.contentSize.width, 1),
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        if textView.string != text {
            context.coordinator.setText(text)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ExpressionTextEditor
        weak var textView: ExpressionNSTextView?
        private var isUpdating = false

        init(_ parent: ExpressionTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView else {
                return
            }

            isUpdating = true
            parent.text = textView.string
            isUpdating = false
        }

        func setText(_ text: String) {
            guard let textView else {
                return
            }

            isUpdating = true
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            isUpdating = false
        }

        func runShortcutPressed() {
            parent.onRun?()
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

final class ExpressionNSTextView: NSTextView {
    var onRun: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if modifiers == [.command], [UInt16(36), UInt16(76)].contains(event.keyCode) {
            onRun?()
            return
        }

        super.keyDown(with: event)
    }
}
