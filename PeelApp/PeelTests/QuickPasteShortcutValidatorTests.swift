import AppKit
import XCTest
@testable import Peel

final class QuickPasteShortcutValidatorTests: XCTestCase {
    func testValidatorRejectsShortcutWithoutMainModifier() {
        let shortcut = QuickPasteShortcut(keyCode: 9, modifiers: [.shift])

        XCTAssertNotNil(QuickPasteShortcutValidator.validationMessage(for: shortcut))
    }

    func testValidatorRejectsReservedAppShortcut() {
        let shortcut = QuickPasteShortcut(keyCode: 9, modifiers: [.command])

        XCTAssertNotNil(QuickPasteShortcutValidator.validationMessage(for: shortcut))
    }

    func testValidatorAllowsSafeShortcut() {
        let shortcut = QuickPasteShortcut(keyCode: 9, modifiers: [.control, .option])

        XCTAssertNil(QuickPasteShortcutValidator.validationMessage(for: shortcut))
    }

    @MainActor
    func testControllerCanRemoveShortcutAndPersistDisabledState() {
        let suiteName = "QuickPasteShortcutValidatorTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let controller = QuickPasteController(userDefaults: userDefaults)
        controller.removeShortcut()

        XCTAssertNil(controller.shortcut)

        let reloadedController = QuickPasteController(userDefaults: userDefaults)
        XCTAssertNil(reloadedController.shortcut)
    }

    @MainActor
    func testControllerRestoreDefaultShortcutAfterRemoval() {
        let suiteName = "QuickPasteShortcutValidatorTests.\(#function)"
        let userDefaults = makeUserDefaults(suiteName: suiteName)

        let controller = QuickPasteController(userDefaults: userDefaults)
        controller.removeShortcut()
        controller.restoreDefaultShortcut()

        XCTAssertEqual(controller.shortcut, .default)

        let reloadedController = QuickPasteController(userDefaults: userDefaults)
        XCTAssertEqual(reloadedController.shortcut, .default)
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
