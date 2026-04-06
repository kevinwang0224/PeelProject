import Foundation
import SwiftData

@Model
final class HistoryItem {
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
