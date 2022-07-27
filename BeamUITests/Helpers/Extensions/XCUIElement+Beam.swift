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
    public func clickInTheMiddle() -> XCUIElement {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        return self
    }
    
    @discardableResult
    public func clickForDurationThenDragToInTheMiddle(forDuration duration: TimeInterval, thenDragTo otherElement: XCUIElement) -> XCUIElement {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click(forDuration: duration, thenDragTo: otherElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        return self
    }
    
    @discardableResult
    public func rightClickInTheMiddle() -> XCUIElement {
        self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
        return self
    }
    
    @discardableResult
    public func clickMultipleTimes(times: Int) -> XCUIElement {
        for _ in 1...times {
            waitForIsHittable(self)
            self.tapInTheMiddle()
        }
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
    public func clickClearAndType(_ text: String, _ typeSlowly: Bool = false) -> XCUIElement {
        self.tapInTheMiddle()
        self.clear()
        //reduces flakiness for Big Sur card number typing
        if typeSlowly {
            self.typeSlowly(text, everyNChar: 3)
        } else {
            self.typeText(text)
        }
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
    public func focusAndTypeTextOnExistence(_ text: String,_ clearTextField: Bool = false) -> XCUIElement {
        _ = self.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        self.tapInTheMiddle()
        if clearTextField {
            self.clear()
        }
        self.typeText(text)
        return self
    }
    
    public func getSize() -> (width: CGFloat, height: CGFloat) {
        return (self.frame.size.width, self.frame.size.height)
    }
    
    public func isSettingEnabled() -> Bool {
        return (self.value as? Int == 1)
    }
    
    public func getStringValue() -> String {
        return self.value as? String ?? "ERROR:failed to fetch string value from " + self.identifier
    }
}
