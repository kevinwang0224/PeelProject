import Foundation

extension String {
    var isValidJSON: Bool {
        JSONFormatterService.validate(self)
    }

    var prettyJSON: String? {
        switch JSONFormatterService.format(self, style: .pretty) {
        case .success(let result):
            return result
        case .failure:
            return nil
        }
    }

    var compactJSON: String? {
        switch JSONFormatterService.format(self, style: .compact) {
        case .success(let result):
            return result
        case .failure:
            return nil
        }
    }

    var jsonByteSize: String {
        let bytes = utf8.count
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    var jsonTitle: String {
        guard let data = data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else {
            return "Invalid JSON"
        }

        if let dictionary = object as? [String: Any] {
            if let firstKey = dictionary.keys.sorted().first {
                return "{ \"\(firstKey)\" ... } (\(dictionary.count) keys)"
            }
            return "{ } (empty)"
        }

        if let array = object as? [Any] {
            return "[ ... ] (\(array.count) items)"
        }

        return "JSON Value"
    }
}
