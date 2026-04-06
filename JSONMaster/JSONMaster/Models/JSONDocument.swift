import Foundation

struct JSONDocument {
    enum JSONType: String {
        case object = "Object"
        case array = "Array"
        case string = "String"
        case number = "Number"
        case boolean = "Boolean"
        case null = "Null"
        case unknown = "Unknown"
    }

    let raw: String
    let formatted: String
    let type: JSONType
    let size: Int
    let keyCount: Int

    init(raw: String) {
        self.raw = raw
        size = raw.utf8.count

        guard let data = raw.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            formatted = raw
            type = .unknown
            keyCount = 0
            return
        }

        switch jsonObject {
        case let dictionary as [String: Any]:
            type = .object
            keyCount = dictionary.count
        case let array as [Any]:
            type = .array
            keyCount = array.count
        case is String:
            type = .string
            keyCount = 0
        case is NSNumber:
            if CFGetTypeID(jsonObject as CFTypeRef) == CFBooleanGetTypeID() {
                type = .boolean
            } else {
                type = .number
            }
            keyCount = 0
        case is NSNull:
            type = .null
            keyCount = 0
        default:
            type = .unknown
            keyCount = 0
        }

        if let prettyData = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        ),
            let prettyString = String(data: prettyData, encoding: .utf8) {
            formatted = prettyString
        } else {
            formatted = raw
        }
    }
}
