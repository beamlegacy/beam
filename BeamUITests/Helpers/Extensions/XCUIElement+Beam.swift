import Foundation
import XCTest

extension XCUIElement: WaitHelper {
    
    public func clear() {
        ShortcutsHelper().shortcutActionInvoke(action: .selectAll)
        XCUIApplication().typeKey(.delete, modifierFlags: .function)
    }

    @discardableResult
    public func tapInTheMiddle() -> XCUIElement {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return self
    }

    @discardableResult
    public func hoverInTheMiddle() -> XCUIElement {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        return self
    }
    
    @discardableResult
    public func doubleTapInTheMiddle() -> XCUIElement {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleTap()
        return self
    }

    @discardableResult
    public func typeSlowly(_ text: String, everyNChar: Int) -> XCUIElement {
        for c in text.split(every: everyNChar) {
            self.typeText(c)
        }
        return self
    }

    public func waitForNonExistence(timeout: TimeInterval, for testCase: XCTestCase){
        let doesNotExistPredicate = NSPredicate(format: "exists == FALSE")
        let expectation = testCase.expectation(for: doesNotExistPredicate, evaluatedWith: self, handler: nil)
        testCase.wait(for: [expectation], timeout: timeout)
    }
    
    @discardableResult
    public func clickOnHittable() -> XCUIElement {
        _ = self.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        BaseTest.waitForIsHittable(self)
        self.click()
        return self
    }
    
    @discardableResult
    public func clickOnExistence() -> XCUIElement {
        _ = self.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        self.click()
        return self
    }
    
    @discardableResult
    public func clickOnEnabled() -> XCUIElement {
        _ = self.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        waitForIsEnabled(self)
        self.click()
        return self
    }
    
    @discardableResult
    public func clickAndType(_ text: String) -> XCUIElement {
        self.tapInTheMiddle()
        self.typeText(text)
        return self
    }
    
    @discardableResult
    public func clickClearAndType(_ text: String) -> XCUIElement {
        self.tapInTheMiddle()
        self.clear()
        self.typeText(text)
        return self
    }

    @discardableResult
    public func clickIfExists() -> XCUIElement {
        if exists {
            self.click()
        }
        return self
    }
    
    @discardableResult
    public func hoverAndTapInTheMiddle() -> XCUIElement {
        self.hover()
        self.tapInTheMiddle()
        return self
    }
    
    @discardableResult
    public func focusAndTypeTextOnExistence(_ text: String) -> XCUIElement {
        _ = self.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        self.tapInTheMiddle()
        self.typeText(text)
        return self
    }
    
    public func getSize() -> (width: CGFloat, height: CGFloat) {
        return (self.frame.size.width, self.frame.size.height)
    }
}
