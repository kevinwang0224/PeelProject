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

    func testUpdatedLayoutPersistsAcrossInstances() {
        let suiteName = "EditorLayoutSettingsTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let settings = EditorLayoutSettings(userDefaults: userDefaults)
        settings.updateResultLayout(.sideBySide)

        let reloadedSettings = EditorLayoutSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloadedSettings.resultLayout, .sideBySide)
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
