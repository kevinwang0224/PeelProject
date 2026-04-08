import AppKit
import Foundation
import Observation
import SwiftUI

enum PeelSettingsCategory: String, CaseIterable, Identifiable {
    case appearance
    case shortcuts
    case about

    static let storageKey = "peelSettingsCategory"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortcuts:
            return "快捷键"
        case .appearance:
            return "外观"
        case .about:
            return "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .shortcuts:
            return "keyboard"
        case .appearance:
            return "paintbrush"
        case .about:
            return "info.circle"
        }
    }
}

enum ExtractionResultLayout: String, CaseIterable, Identifiable {
    case sideBySide
    case stacked

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

enum AppThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appThemePreference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "系统"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var windowAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    func resolvedColorScheme(systemColorScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system:
            return systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func resolvedWindowAppearance(systemColorScheme: ColorScheme) -> NSAppearance {
        switch resolvedColorScheme(systemColorScheme: systemColorScheme) {
        case .light:
            return NSAppearance(named: .aqua)!
        case .dark:
            return NSAppearance(named: .darkAqua)!
        @unknown default:
            return NSAppearance(named: .aqua)!
        }
    }
}

@MainActor
@Observable
final class EditorLayoutSettings {
    static let defaultFontSize: CGFloat = 12
    static let minimumFontSize: CGFloat = 10
    static let maximumFontSize: CGFloat = 24

    static let interfaceFontSizeKey = "interfaceFontSize"
    static let editorFontSizeKey = "editorFontSize"

    var appThemePreference: AppThemePreference {
        didSet {
            guard appThemePreference != oldValue else {
                return
            }

            userDefaults.set(appThemePreference.rawValue, forKey: AppThemePreference.storageKey)
        }
    }

    var resultLayout: ExtractionResultLayout {
        didSet {
            guard resultLayout != oldValue else {
                return
            }

            userDefaults.set(resultLayout.rawValue, forKey: ExtractionResultLayout.storageKey)
        }
    }

    var interfaceFontSize: CGFloat {
        didSet {
            let clamped = Self.clampedFontSize(interfaceFontSize)
            if clamped != interfaceFontSize {
                interfaceFontSize = clamped
                return
            }

            guard interfaceFontSize != oldValue else {
                return
            }

            userDefaults.set(Double(interfaceFontSize), forKey: Self.interfaceFontSizeKey)
        }
    }

    var editorFontSize: CGFloat {
        didSet {
            let clamped = Self.clampedFontSize(editorFontSize)
            if clamped != editorFontSize {
                editorFontSize = clamped
                return
            }

            guard editorFontSize != oldValue else {
                return
            }

            userDefaults.set(Double(editorFontSize), forKey: Self.editorFontSizeKey)
        }
    }

    @ObservationIgnored
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let storedValue = userDefaults.string(forKey: AppThemePreference.storageKey),
           let storedTheme = AppThemePreference(rawValue: storedValue) {
            appThemePreference = storedTheme
        } else {
            appThemePreference = .system
        }

        if let storedValue = userDefaults.string(forKey: ExtractionResultLayout.storageKey),
           let storedLayout = ExtractionResultLayout(rawValue: storedValue) {
            resultLayout = storedLayout
        } else {
            resultLayout = .sideBySide
        }

        interfaceFontSize = Self.storedFontSize(
            forKey: Self.interfaceFontSizeKey,
            userDefaults: userDefaults
        )
        editorFontSize = Self.storedFontSize(
            forKey: Self.editorFontSizeKey,
            userDefaults: userDefaults
        )
    }

    func updateResultLayout(_ layout: ExtractionResultLayout) {
        resultLayout = layout
    }

    func updateAppThemePreference(_ theme: AppThemePreference) {
        appThemePreference = theme
    }

    func updateInterfaceFontSize(_ size: CGFloat) {
        interfaceFontSize = size
    }

    func updateEditorFontSize(_ size: CGFloat) {
        editorFontSize = size
    }

    private static func storedFontSize(forKey key: String, userDefaults: UserDefaults) -> CGFloat {
        guard let storedValue = userDefaults.object(forKey: key) as? NSNumber else {
            return defaultFontSize
        }

        return clampedFontSize(CGFloat(truncating: storedValue))
    }

    private static func clampedFontSize(_ size: CGFloat) -> CGFloat {
        min(max(size, minimumFontSize), maximumFontSize)
    }
}

@MainActor
@Observable
final class SettingsNavigationState {
    var selectedCategory: PeelSettingsCategory {
        didSet {
            guard selectedCategory != oldValue else {
                return
            }

            userDefaults.set(selectedCategory.rawValue, forKey: PeelSettingsCategory.storageKey)
        }
    }

    @ObservationIgnored
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let storedValue = userDefaults.string(forKey: PeelSettingsCategory.storageKey),
           let storedCategory = PeelSettingsCategory(rawValue: storedValue) {
            selectedCategory = storedCategory
        } else {
            selectedCategory = .appearance
        }
    }

    func select(_ category: PeelSettingsCategory) {
        selectedCategory = category
    }
}
