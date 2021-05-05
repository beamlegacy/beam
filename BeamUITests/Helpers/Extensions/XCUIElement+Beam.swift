import Foundation
import XCTest

extension XCUIElement {
    public func clear() {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }

        let lowerRightCorner = self.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9))
        lowerRightCorner.click() // lowerRightCorner.tap() // Might do that for iOS/iPad.

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        XCUIApplication().typeText(deleteString)
    }

    public func tapInTheMiddle() {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    public func typeSlowly(_ text: String, everyNChar: Int) {
        for c in text.split(every: everyNChar) {
            self.typeText(c)
        }
    }
}
