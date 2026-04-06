import Foundation
import Observation

enum ExtractionResultLayout: String, CaseIterable, Identifiable {
    case stacked
    case sideBySide

    static let storageKey = "extractionResultLayout"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stacked:
            return "上下显示"
        case .sideBySide:
            return "左右显示"
        }
    }

    var detail: String {
        switch self {
        case .stacked:
            return "上面显示原始 JSON，下面显示结果"
        case .sideBySide:
            return "左边显示原始 JSON，右边显示结果"
        }
    }
}

@MainActor
@Observable
final class EditorLayoutSettings {
    var resultLayout: ExtractionResultLayout {
        didSet {
            guard resultLayout != oldValue else {
                return
            }

            userDefaults.set(resultLayout.rawValue, forKey: ExtractionResultLayout.storageKey)
        }
    }

    @ObservationIgnored
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let storedValue = userDefaults.string(forKey: ExtractionResultLayout.storageKey),
           let storedLayout = ExtractionResultLayout(rawValue: storedValue) {
            resultLayout = storedLayout
        } else {
            resultLayout = .sideBySide
        }
    }

    func updateResultLayout(_ layout: ExtractionResultLayout) {
        resultLayout = layout
    }
}
