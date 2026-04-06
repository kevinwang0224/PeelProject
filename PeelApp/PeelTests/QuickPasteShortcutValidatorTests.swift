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
}
