import Foundation
import XCTest

extension XCUIElement {
    public func clear() {
        XCUIApplication().typeKey("a", modifierFlags: .command)
        XCUIApplication().typeKey(.delete, modifierFlags: .function)
    }

    public func tapInTheMiddle() {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    public func typeSlowly(_ text: String, everyNChar: Int) {
        for c in text.split(every: everyNChar) {
            self.typeText(c)
        }
    }

    public func waitForNonExistence(timeout: TimeInterval, for testCase: XCTestCase){
        let doesNotExistPredicate = NSPredicate(format: "exists == FALSE")
        let expectation = testCase.expectation(for: doesNotExistPredicate, evaluatedWith: self, handler: nil)
        testCase.wait(for: [expectation], timeout: timeout)
    }
}
