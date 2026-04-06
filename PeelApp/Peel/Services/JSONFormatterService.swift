import Foundation

enum JSONFormatStyle {
    case pretty
    case compact
    case sortedKeys
}

struct JSONValidationIssue: Equatable {
    let message: String
    let line: Int
    let column: Int
    let utf16Index: Int

    var displayMessage: String {
        "Line \(line), Column \(column): \(message)"
    }

    func highlightRange(in text: String) -> NSRange? {
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return nil
        }

        let anchor = preferredAnchor(in: nsText)
        let character = nsText.character(at: anchor)

        if character == 34 {
            return quotedRange(startingAt: anchor, in: nsText)
        }

        if isTokenCharacter(character) {
            return tokenRange(around: anchor, in: nsText)
        }

        return NSRange(location: anchor, length: 1)
    }

    func lineRange(in text: String) -> NSRange? {
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return nil
        }

        let anchor = preferredAnchor(in: nsText)
        return nsText.lineRange(for: NSRange(location: anchor, length: 0))
    }

    private func preferredAnchor(in text: NSString) -> Int {
        let clampedLocation = min(max(utf16Index, 0), max(text.length - 1, 0))
        let lineRange = text.lineRange(for: NSRange(location: clampedLocation, length: 0))

        if !isWhitespace(text.character(at: clampedLocation)) {
            return clampedLocation
        }

        var forwardIndex = clampedLocation
        while forwardIndex < NSMaxRange(lineRange) {
            if !isWhitespace(text.character(at: forwardIndex)) {
                return forwardIndex
            }
            forwardIndex += 1
        }

        var backwardIndex = max(lineRange.location, clampedLocation - 1)
        while backwardIndex >= lineRange.location {
            if !isWhitespace(text.character(at: backwardIndex)) {
                return backwardIndex
            }
            if backwardIndex == lineRange.location {
                break
            }
            backwardIndex -= 1
        }

        return clampedLocation
    }

    private func quotedRange(startingAt location: Int, in text: NSString) -> NSRange {
        var currentIndex = location + 1
        while currentIndex < text.length {
            if text.character(at: currentIndex) == 34 && !isEscapedQuote(at: currentIndex, in: text) {
                return NSRange(location: location, length: currentIndex - location + 1)
            }
            currentIndex += 1
        }

        return NSRange(location: location, length: min(text.length - location, 1))
    }

    private func tokenRange(around location: Int, in text: NSString) -> NSRange {
        var start = location
        var end = location

        while start > 0 && isTokenCharacter(text.character(at: start - 1)) {
            start -= 1
        }

        while end + 1 < text.length && isTokenCharacter(text.character(at: end + 1)) {
            end += 1
        }

        return NSRange(location: start, length: end - start + 1)
    }

    private func isEscapedQuote(at index: Int, in text: NSString) -> Bool {
        guard index > 0 else {
            return false
        }

        var slashCount = 0
        var cursor = index - 1
        while cursor >= 0 && text.character(at: cursor) == 92 {
            slashCount += 1
            if cursor == 0 {
                break
            }
            cursor -= 1
        }

        return slashCount.isMultiple(of: 2) == false
    }

    private func isWhitespace(_ character: unichar) -> Bool {
        guard let scalar = UnicodeScalar(character) else {
            return false
        }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    private func isTokenCharacter(_ character: unichar) -> Bool {
        guard let scalar = UnicodeScalar(character) else {
            return false
        }
        return CharacterSet.alphanumerics.contains(scalar) || character == 95
    }
}

enum JSONError: LocalizedError {
    case invalidJSON(String)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail):
            return "Invalid JSON: \(detail)"
        case .encodingError:
            return "Failed to encode JSON string"
        }
    }
}

struct JSONFormatterService {
    static func format(
        _ input: String,
        style: JSONFormatStyle = .pretty
    ) -> Result<String, JSONError> {
        let jsonObject: Any
        switch parse(input) {
        case .success(let object):
            jsonObject = object
        case .failure(let error):
            return .failure(error)
        }

        var options: JSONSerialization.WritingOptions = [.fragmentsAllowed]
        switch style {
        case .pretty:
            options.formUnion([.prettyPrinted, .sortedKeys])
        case .compact:
            break
        case .sortedKeys:
            options.formUnion([.prettyPrinted, .sortedKeys])
        }

        do {
            let outputData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
            guard let output = String(data: outputData, encoding: .utf8) else {
                return .failure(.encodingError)
            }
            return .success(output)
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    static func validate(_ input: String) -> Bool {
        if case .success = parse(input) {
            return true
        }

        return false
    }

    static func validationIssue(_ input: String) -> JSONValidationIssue? {
        guard let data = input.data(using: .utf8) else {
            return nil
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            return nil
        } catch {
            let nsError = error as NSError
            let utf8Index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int ?? 0
            let summary = errorSummary(from: nsError)
            let location = location(in: input, utf8Index: utf8Index)
            return JSONValidationIssue(
                message: summary,
                line: location.line,
                column: location.column,
                utf16Index: location.utf16Index
            )
        }
    }

    static func minify(_ input: String) -> Result<String, JSONError> {
        format(input, style: .compact)
    }

    static func parse(_ input: String) -> Result<Any, JSONError> {
        guard let data = input.data(using: .utf8) else {
            return .failure(.encodingError)
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            return .success(unwrappedJSONObject(from: jsonObject))
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    private static func unwrappedJSONObject(from jsonObject: Any, depth: Int = 0) -> Any {
        guard depth < 8, let stringValue = jsonObject as? String else {
            return jsonObject
        }

        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstCharacter = trimmed.first,
              firstCharacter == "{" || firstCharacter == "[" || firstCharacter == "\"" else {
            return jsonObject
        }

        guard let nestedData = stringValue.data(using: .utf8),
              let nestedObject = try? JSONSerialization.jsonObject(
                  with: nestedData,
                  options: .fragmentsAllowed
              ) else {
            return jsonObject
        }

        return unwrappedJSONObject(from: nestedObject, depth: depth + 1)
    }

    private static func errorSummary(from error: NSError) -> String {
        let rawMessage = (error.userInfo["NSDebugDescription"] as? String) ?? error.localizedDescription
        if let range = rawMessage.range(of: " around line ") {
            return String(rawMessage[..<range.lowerBound])
        }
        return rawMessage.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    }

    private static func location(in text: String, utf8Index: Int) -> (line: Int, column: Int, utf16Index: Int) {
        let clampedUTF8Index = min(max(utf8Index, 0), text.utf8.count)
        let utf8View = text.utf8
        let utf8ViewIndex = utf8View.index(utf8View.startIndex, offsetBy: clampedUTF8Index)
        let stringIndex = String.Index(utf8ViewIndex, within: text) ?? text.endIndex
        let utf16Index = stringIndex.utf16Offset(in: text)

        var line = 1
        var column = 1
        var currentIndex = text.startIndex

        while currentIndex < stringIndex {
            if text[currentIndex] == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            currentIndex = text.index(after: currentIndex)
        }

        return (line, column, utf16Index)
    }
}
