import Foundation
import SwiftData

@Model
final class HistoryItem {
    static func defaultTitle(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    var id: UUID
    var title: String
    var rawJSON: String
    var formattedJSON: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(
        title: String = "Untitled",
        rawJSON: String,
        formattedJSON: String = ""
    ) {
        id = UUID()
        self.title = title
        self.rawJSON = rawJSON
        self.formattedJSON = formattedJSON
        createdAt = Date()
        updatedAt = Date()
        isPinned = false
    }
}
