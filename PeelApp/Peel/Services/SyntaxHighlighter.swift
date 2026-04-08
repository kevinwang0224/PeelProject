import AppKit
import Foundation

struct SyntaxHighlighter {
    struct Theme {
        enum Variant {
            case light
            case dark
        }

        let variant: Variant
        let key: NSColor
        let string: NSColor
        let number: NSColor
        let boolean: NSColor
        let null: NSColor
        let brace: NSColor
        let background: NSColor
        let defaultText: NSColor

        static let light = Theme(
            variant: .light,
            key: NSColor(red: 0.16, green: 0.30, blue: 0.60, alpha: 1.0),
            string: NSColor(red: 0.76, green: 0.24, blue: 0.16, alpha: 1.0),
            number: NSColor(red: 0.11, green: 0.51, blue: 0.47, alpha: 1.0),
            boolean: NSColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0),
            null: .systemGray,
            brace: .labelColor,
            background: .textBackgroundColor,
            defaultText: .labelColor
        )

        static let dark = Theme(
            variant: .dark,
            key: NSColor(red: 0.58, green: 0.79, blue: 0.93, alpha: 1.0),
            string: NSColor(red: 0.81, green: 0.56, blue: 0.42, alpha: 1.0),
            number: NSColor(red: 0.71, green: 0.84, blue: 0.59, alpha: 1.0),
            boolean: NSColor(red: 0.78, green: 0.57, blue: 0.86, alpha: 1.0),
            null: .systemGray,
            brace: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0),
            background: .textBackgroundColor,
            defaultText: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        )
    }

    private enum RegexStore {
        static let key = compile("\"([^\"\\\\]|\\\\.)*\"\\s*:")
        static let valueString = compile(":\\s*\"([^\"\\\\]|\\\\.)*\"")
        static let arrayString = compile("(?<=\\[\\s{0,100}|,\\s{0,100})\"([^\"\\\\]|\\\\.)*\"")
        static let number = compile("(?<=:\\s{0,10}|\\[\\s{0,10}|,\\s{0,10})-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?")
        static let boolean = compile("\\b(true|false)\\b")
        static let null = compile("\\bnull\\b")
        static let brace = compile("[\\{\\}\\[\\]]")
    }

    static func highlight(_ json: String, theme: Theme, font: NSFont) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: json,
            attributes: [
                .foregroundColor: theme.defaultText,
                .font: font
            ]
        )

        let text = json as NSString
        let fullRange = NSRange(location: 0, length: text.length)

        applyMatches(
            regex: RegexStore.key,
            in: json,
            range: fullRange
        ) { match in
            var highlightRange = match.range
            let matchedString = text.substring(with: highlightRange)
            if let colonIndex = matchedString.lastIndex(of: ":") {
                let offset = matchedString.distance(from: matchedString.startIndex, to: colonIndex)
                highlightRange.length = offset
            }
            attributed.addAttribute(.foregroundColor, value: theme.key, range: highlightRange)
        }

        applyMatches(
            regex: RegexStore.valueString,
            in: json,
            range: fullRange
        ) { match in
            let matchedString = text.substring(with: match.range)
            guard let quoteIndex = matchedString.firstIndex(of: "\"") else {
                return
            }

            let offset = matchedString.distance(from: matchedString.startIndex, to: quoteIndex)
            let highlightRange = NSRange(
                location: match.range.location + offset,
                length: match.range.length - offset
            )
            attributed.addAttribute(.foregroundColor, value: theme.string, range: highlightRange)
        }

        applyMatches(
            regex: RegexStore.arrayString,
            in: json,
            range: fullRange
        ) { match in
            attributed.addAttribute(.foregroundColor, value: theme.string, range: match.range)
        }

        applyMatches(
            regex: RegexStore.number,
            in: json,
            range: fullRange
        ) { match in
            attributed.addAttribute(.foregroundColor, value: theme.number, range: match.range)
        }

        applyMatches(regex: RegexStore.boolean, in: json, range: fullRange) { match in
            attributed.addAttribute(.foregroundColor, value: theme.boolean, range: match.range)
        }

        applyMatches(regex: RegexStore.null, in: json, range: fullRange) { match in
            attributed.addAttribute(.foregroundColor, value: theme.null, range: match.range)
        }

        applyMatches(regex: RegexStore.brace, in: json, range: fullRange) { match in
            attributed.addAttribute(.foregroundColor, value: theme.brace, range: match.range)
        }

        return attributed
    }

    static func currentTheme() -> Theme {
        guard let app = NSApp else {
            return .light
        }

        let isDark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }

    private static func applyMatches(
        regex: NSRegularExpression,
        in json: String,
        range: NSRange,
        using body: (NSTextCheckingResult) -> Void
    ) {
        regex.matches(in: json, range: range).forEach(body)
    }

    private static func compile(_ pattern: String) -> NSRegularExpression {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            preconditionFailure("Invalid syntax highlight pattern: \(pattern)")
        }

        return regex
    }
}
