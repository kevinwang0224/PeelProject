import Foundation

enum JSONFormatStyle {
    case pretty
    case compact
    case sortedKeys
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
        guard let data = input.data(using: .utf8) else {
            return .failure(.encodingError)
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
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
        guard let data = input.data(using: .utf8) else {
            return false
        }

        return (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil
    }

    static func minify(_ input: String) -> Result<String, JSONError> {
        format(input, style: .compact)
    }
}
