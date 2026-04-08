import AppKit
import SwiftUI
import XCTest
@testable import Peel

@MainActor
final class EditorLayoutSettingsTests: XCTestCase {
    func testDefaultsToSideBySideLayout() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let settings = EditorLayoutSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.resultLayout, .sideBySide)
    }

    func testLayoutOptionsShowSideBySideFirst() {
        XCTAssertEqual(ExtractionResultLayout.allCases.first, .sideBySide)
    }

    func testSettingsCategoriesShowAppearanceFirst() {
        XCTAssertEqual(PeelSettingsCategory.allCases.first, .appearance)
    }

    func testUpdatedLayoutPersistsAcrossInstances() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let settings = EditorLayoutSettings(userDefaults: userDefaults)
        settings.updateResultLayout(.sideBySide)

        let reloadedSettings = EditorLayoutSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloadedSettings.resultLayout, .sideBySide)
    }

    func testFontSizesDefaultToTwelve() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let settings = EditorLayoutSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.interfaceFontSize, 12)
        XCTAssertEqual(settings.editorFontSize, 12)
    }

    func testThemeDefaultsToSystem() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let settings = EditorLayoutSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.appThemePreference, .system)
    }

    func testUpdatedFontSizesPersistAcrossInstances() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let settings = EditorLayoutSettings(userDefaults: userDefaults)
        settings.updateInterfaceFontSize(14)
        settings.updateEditorFontSize(16)

        let reloadedSettings = EditorLayoutSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloadedSettings.interfaceFontSize, 14)
        XCTAssertEqual(reloadedSettings.editorFontSize, 16)
    }

    func testUpdatedThemePersistsAcrossInstances() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let settings = EditorLayoutSettings(userDefaults: userDefaults)
        settings.updateAppThemePreference(.dark)

        let reloadedSettings = EditorLayoutSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloadedSettings.appThemePreference, .dark)
    }

    func testThemePreferenceMapsToExpectedWindowAppearance() {
        XCTAssertNil(AppThemePreference.system.windowAppearance)
        XCTAssertEqual(AppThemePreference.light.windowAppearance?.name, .aqua)
        XCTAssertEqual(AppThemePreference.dark.windowAppearance?.name, .darkAqua)
    }

    func testThemePreferenceResolvesSystemChoiceImmediately() {
        XCTAssertEqual(
            AppThemePreference.system.resolvedColorScheme(systemColorScheme: .dark),
            .dark
        )
        XCTAssertEqual(
            AppThemePreference.system.resolvedWindowAppearance(systemColorScheme: .dark).name,
            .darkAqua
        )
        XCTAssertEqual(
            AppThemePreference.system.resolvedColorScheme(systemColorScheme: .light),
            .light
        )
    }

    func testSyntaxHighlighterUsesProvidedColorScheme() {
        XCTAssertEqual(SyntaxHighlighter.currentTheme(for: .light).variant, .light)
        XCTAssertEqual(SyntaxHighlighter.currentTheme(for: .dark).variant, .dark)
    }

    func testSettingsNavigationDefaultsToAppearanceCategory() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let navigationState = SettingsNavigationState(userDefaults: userDefaults)

        XCTAssertEqual(navigationState.selectedCategory, .appearance)
    }

    func testSettingsNavigationPersistsSelectedCategory() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let navigationState = SettingsNavigationState(userDefaults: userDefaults)
        navigationState.select(.about)

        let reloadedNavigationState = SettingsNavigationState(userDefaults: userDefaults)
        XCTAssertEqual(reloadedNavigationState.selectedCategory, .about)
    }

    private func makeUserDefaults(suiteName: String) -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        return userDefaults
    }
}
