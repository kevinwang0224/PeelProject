import Foundation

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated // 使用缩写，如 "1 min. ago"
        // 如果想要更简洁如 "1m"，可以自定义逻辑，但 .abbreviated 是最平衡的
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
