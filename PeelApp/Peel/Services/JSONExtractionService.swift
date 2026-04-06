import Foundation
import JavaScriptCore

enum ExtractionMode: String, CaseIterable, Identifiable {
    case javaScript = "JavaScript"
    case jsonPath = "JSONPath"

    var id: String { rawValue }

    var placeholder: String {
        switch self {
        case .javaScript:
            return "data.user.name"
        case .jsonPath:
            return "$.items[0]"
        }
    }

    var helpText: String {
        switch self {
        case .javaScript:
            return "把当前 JSON 当成 data 使用，例如 data.items.map(item => item.id)"
        case .jsonPath:
            return "支持 $, .key, ['key'], [0], *, ..key 这些常用写法"
        }
    }
}

struct ExtractionRunResult {
    enum Status: Equatable {
        case idle
        case success
        case empty
        case error
    }

    let status: Status
    let title: String
    let text: String

    var canCopy: Bool {
        status == .success
    }

    static let idle = ExtractionRunResult(
        status: .idle,
        title: "Result",
        text: "输入表达式后，结果会显示在这里。"
    )
}

enum JSONExtractionService {
    static func run(
        input: String,
        query: String,
        mode: ExtractionMode
    ) -> ExtractionRunResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return ExtractionRunResult(
                status: .error,
                title: "Expression Required",
                text: "请输入要执行的表达式。"
            )
        }

        let rootObject: Any
        do {
            rootObject = try parseStrictJSON(input)
        } catch {
            return ExtractionRunResult(
                status: .error,
                title: "Invalid JSON",
                text: "当前内容不是有效 JSON。"
            )
        }

        do {
            switch mode {
            case .javaScript:
                return try runJavaScript(query: trimmedQuery, rootObject: rootObject)
            case .jsonPath:
                return try runJSONPath(query: trimmedQuery, rootObject: rootObject)
            }
        } catch let error as ExtractionError {
            return ExtractionRunResult(
                status: .error,
                title: "Extraction Failed",
                text: error.message
            )
        } catch {
            return ExtractionRunResult(
                status: .error,
                title: "Extraction Failed",
                text: "提取失败，请检查表达式。"
            )
        }
    }

    private static func runJavaScript(query: String, rootObject: Any) throws -> ExtractionRunResult {
        let context = JSContext()
        var thrownMessage: String?
        context?.exceptionHandler = { _, exception in
            thrownMessage = exception?.toString()
        }
        context?.setObject(rootObject, forKeyedSubscript: "data" as NSString)

        guard let value = context?.evaluateScript(query) else {
            throw ExtractionError(message: thrownMessage ?? "表达式没有返回结果。")
        }

        if let thrownMessage {
            throw ExtractionError(message: thrownMessage)
        }

        if value.isUndefined {
            return ExtractionRunResult(
                status: .empty,
                title: "No Result",
                text: "无结果"
            )
        }

        if value.isNull {
            return ExtractionRunResult(status: .success, title: "Result", text: "null")
        }

        if value.isString {
            return ExtractionRunResult(
                status: .success,
                title: "Result",
                text: value.toString()
            )
        }

        if value.isBoolean || value.isNumber {
            return ExtractionRunResult(
                status: .success,
                title: "Result",
                text: value.toString()
            )
        }

        let bridgedObject = value.toObject()
        let rendered = try renderOutput(for: bridgedObject)
        return ExtractionRunResult(status: .success, title: "Result", text: rendered)
    }

    private static func runJSONPath(query: String, rootObject: Any) throws -> ExtractionRunResult {
        var parser = JSONPathParser(query: query)
        let segments = try parser.parse()
        let matches = evaluateJSONPath(segments, rootObject: rootObject)

        guard !matches.isEmpty else {
            return ExtractionRunResult(
                status: .empty,
                title: "No Result",
                text: "无结果"
            )
        }

        if matches.count == 1 {
            let rendered = try renderOutput(for: matches[0])
            return ExtractionRunResult(status: .success, title: "Result", text: rendered)
        }

        let rendered = try renderOutput(for: matches)
        return ExtractionRunResult(status: .success, title: "Result", text: rendered)
    }

    private static func parseStrictJSON(_ input: String) throws -> Any {
        guard let data = input.data(using: .utf8) else {
            throw ExtractionError(message: "JSON 编码失败。")
        }

        return try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }

    private static func renderOutput(for value: Any?) throws -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }

            return number.stringValue
        case is NSNull:
            return "null"
        case let array as [Any]:
            return try prettyJSONString(for: array)
        case let dictionary as [String: Any]:
            return try prettyJSONString(for: dictionary)
        case nil:
            return "null"
        default:
            if JSONSerialization.isValidJSONObject(value as Any) {
                return try prettyJSONString(for: value as Any)
            }

            return String(describing: value as Any)
        }
    }

    private static func prettyJSONString(for value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ExtractionError(message: "结果无法转成文本。")
        }

        return string
    }

    private static func evaluateJSONPath(_ segments: [JSONPathSegment], rootObject: Any) -> [Any] {
        var currentNodes = [rootObject]

        for segment in segments {
            currentNodes = apply(segment, to: currentNodes)
        }

        return currentNodes
    }

    private static func apply(_ segment: JSONPathSegment, to nodes: [Any]) -> [Any] {
        switch segment {
        case .child(let key):
            return nodes.compactMap { node in
                guard let dictionary = node as? [String: Any] else {
                    return nil
                }

                return dictionary[key]
            }

        case .index(let index):
            return nodes.compactMap { node in
                guard let array = node as? [Any], array.indices.contains(index) else {
                    return nil
                }

                return array[index]
            }

        case .wildcard:
            return nodes.flatMap { node in
                if let dictionary = node as? [String: Any] {
                    return dictionary.keys.sorted().compactMap { dictionary[$0] }
                }

                if let array = node as? [Any] {
                    return array
                }

                return []
            }

        case .recursiveChild(let key):
            return nodes.flatMap { node in
                recursiveMatches(in: node, matching: key)
            }

        case .recursiveWildcard:
            return nodes.flatMap { node in
                recursiveMatches(in: node, matching: nil)
            }
        }
    }

    private static func recursiveMatches(in node: Any, matching key: String?) -> [Any] {
        var results: [Any] = []

        if let dictionary = node as? [String: Any] {
            for currentKey in dictionary.keys.sorted() {
                guard let value = dictionary[currentKey] else {
                    continue
                }

                if key == nil || key == currentKey {
                    results.append(value)
                }

                results.append(contentsOf: recursiveMatches(in: value, matching: key))
            }
        } else if let array = node as? [Any] {
            for value in array {
                if key == nil {
                    results.append(value)
                }

                results.append(contentsOf: recursiveMatches(in: value, matching: key))
            }
        }

        return results
    }
}

private struct ExtractionError: Error {
    let message: String
}

private enum JSONPathSegment {
    case child(String)
    case index(Int)
    case wildcard
    case recursiveChild(String)
    case recursiveWildcard
}

private struct JSONPathParser {
    private let characters: [Character]
    private var index = 0

    init(query: String) {
        characters = Array(query)
    }

    mutating func parse() throws -> [JSONPathSegment] {
        skipWhitespace()

        guard consume("$") else {
            throw ExtractionError(message: "JSONPath 需要从 $ 开头。")
        }

        var segments: [JSONPathSegment] = []

        while true {
            skipWhitespace()

            guard let current = currentCharacter else {
                break
            }

            if current == "." {
                advance()

                if consume(".") {
                    if consume("*") {
                        segments.append(.recursiveWildcard)
                    } else {
                        segments.append(.recursiveChild(try parseIdentifier()))
                    }
                } else if consume("*") {
                    segments.append(.wildcard)
                } else {
                    segments.append(.child(try parseIdentifier()))
                }
            } else if current == "[" {
                advance()
                skipWhitespace()

                if consume("*") {
                    skipWhitespace()
                    try expect("]")
                    segments.append(.wildcard)
                } else if let quote = currentCharacter, quote == "\"" || quote == "'" {
                    let key = try parseQuotedString()
                    skipWhitespace()
                    try expect("]")
                    segments.append(.child(key))
                } else {
                    let indexValue = try parseIndex()
                    skipWhitespace()
                    try expect("]")
                    segments.append(.index(indexValue))
                }
            } else {
                throw ExtractionError(message: "JSONPath 里有不能识别的内容。")
            }
        }

        return segments
    }

    private var currentCharacter: Character? {
        guard index < characters.count else {
            return nil
        }

        return characters[index]
    }

    private mutating func advance() {
        index += 1
    }

    private mutating func skipWhitespace() {
        while let currentCharacter, currentCharacter.isWhitespace {
            advance()
        }
    }

    private mutating func consume(_ character: Character) -> Bool {
        guard currentCharacter == character else {
            return false
        }

        advance()
        return true
    }

    private mutating func expect(_ character: Character) throws {
        guard consume(character) else {
            throw ExtractionError(message: "JSONPath 缺少 \(character)。")
        }
    }

    private mutating func parseIdentifier() throws -> String {
        let start = index

        while let currentCharacter,
              currentCharacter.isLetter || currentCharacter.isNumber || currentCharacter == "_" || currentCharacter == "-" {
            advance()
        }

        guard start != index else {
            throw ExtractionError(message: "JSONPath 缺少字段名。")
        }

        return String(characters[start..<index])
    }

    private mutating func parseIndex() throws -> Int {
        let start = index

        while let currentCharacter, currentCharacter.isNumber {
            advance()
        }

        guard start != index,
              let value = Int(String(characters[start..<index])) else {
            throw ExtractionError(message: "数组下标写法不对。")
        }

        return value
    }

    private mutating func parseQuotedString() throws -> String {
        guard let quote = currentCharacter else {
            throw ExtractionError(message: "字段名写法不对。")
        }

        advance()
        var output = ""

        while let currentCharacter {
            if currentCharacter == quote {
                advance()
                return output
            }

            if currentCharacter == "\\" {
                advance()

                guard let escapedCharacter = self.currentCharacter else {
                    throw ExtractionError(message: "字段名转义不完整。")
                }

                switch escapedCharacter {
                case "\\", "\"", "'":
                    output.append(escapedCharacter)
                case "n":
                    output.append("\n")
                case "t":
                    output.append("\t")
                default:
                    output.append(escapedCharacter)
                }

                advance()
                continue
            }

            output.append(currentCharacter)
            advance()
        }

        throw ExtractionError(message: "字段名没有正确结束。")
    }
}
