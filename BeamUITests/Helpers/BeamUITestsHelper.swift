import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
import Fakery
import BeamCore

extension XCUIElementQuery: Sequence {
    public typealias Iterator = AnyIterator<XCUIElement>
    public func makeIterator() -> Iterator {
        var index = UInt(0)
        return AnyIterator {
            guard index < self.count else { return nil }

            let element = self.element(boundBy: Int(index))
            index += 1
            return element
        }
    }
}

class BeamUITestsHelper {
    var app: XCUIApplication!

    let helper = ShortcutsHelper()

    init(_ app: XCUIApplication) {
        self.app = app
    }

    func moveMouseOutOfTheWay() {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).hover()
    }
    
    func showLogs() {
        let menu = XCUIApplication().menuItems["Show Logs"]
        menu.tap()
    }

    func showJournal() {
        helper.shortcutActionInvoke(action: .showJournal)
    }

    // Doesn't work 
    func logsValue() -> String? {
        let allLogsWindow = XCUIApplication().windows["All Logs"]
        allLogsWindow.clickOnExistence()
        return allLogsWindow.scrollViews.containing(.button, identifier: "Bottom").element.getStringValue()
    }

    func makeDeviceScreenShot() {
        let screenshot = XCUIScreen.main.screenshot()
        saveAttachment(screenshot)
    }

    func makeAppScreenShots() {
        for (index, window) in self.app.windows.enumerated() {
            let screenshot = window.screenshot()
            saveAttachment(screenshot, name: "Window\(index).png")
        }
    }

    func makeElementScreenShot(_ element: XCUIElement) {
        let screenshot = element.screenshot()
        saveAttachment(screenshot)
    }

    private func saveAttachment(_ screenshot: XCUIScreenshot, name: String? = nil) {
        let fullScreenshotAttachment = XCTAttachment(screenshot: screenshot)
        fullScreenshotAttachment.lifetime = .keepAlways
        fullScreenshotAttachment.name = name
        QuickSpec.current.add(fullScreenshotAttachment)
    }

    func todayDate() -> String {
        return BeamDate.journalNoteTitle()
    }
    
    func addNote(noteTitle: String? = nil) {
        let notePickerField = self.app.textFields[todayDate()].firstMatch
        notePickerField.clickInTheMiddle()
        XCTAssert(notePickerField.waitForExistence(timeout: 4))
        if let title = noteTitle {
            notePickerField.typeText("\(title)\r\r")
        } else {
            notePickerField.typeText("\r")
        }
    }
    
    func assertShootCardPickerLabelPosition(referenceElement: XCUIElement) {
        let PnsFrame = self.app.otherElements.matching(identifier: "ShootFrameSelection")
        let ShootCardPickerLabels = self.app.staticTexts.matching(identifier:"ShootCardPickerLabel")
        let padding: CGFloat = 16
        // expect single label
        XCTAssertEqual(ShootCardPickerLabels.count, 1)
        // Expect ShootCardPicker to be correctly positioned
        XCTAssertEqual(ShootCardPickerLabels.element.frame.width, 41.5, accuracy: 1)
        XCTAssertEqual(ShootCardPickerLabels.element.frame.height, 16.0, accuracy: 1)
        XCTAssertEqual(ShootCardPickerLabels.element.frame.origin.x, referenceElement.frame.origin.x + (referenceElement.frame.width / 2) + padding, accuracy: 10)
        XCTAssertEqual(ShootCardPickerLabels.element.frame.origin.y, referenceElement.frame.origin.y + PnsFrame.element.frame.height, accuracy: 10)
    }
    
    func typeAndEditHardcodedText (_ view: BaseView) -> String {
        view.app.typeText("Typed Text at the row")
        view.typeKeyboardKey(.leftArrow, 4)
        helper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: 4)
        view.typeKeyboardKey(.delete)
        
        helper.shortcutActionInvoke(action: .endOfLine)
        helper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: 4)
        view.typeKeyboardKey(.delete)
        
        helper.shortcutActionInvoke(action: .beginOfLine)
        view.typeKeyboardKey(.rightArrow, 4)
        helper.shortcutActionInvokeRepeatedly(action: .selectOnRight, numberOfTimes: 4)
        view.typeKeyboardKey(.space)
        let expectedTextAfterChange = "Type xt at"
        return expectedTextAfterChange
    }
    
}

extension BeamUITestsHelper {
    func randomSearchTerm() -> String {
        Faker(locale: "en-US").commerce.color()
    }
    func randomEmail() -> String {
        Faker(locale: "en-US").internet.email()
    }
    func randomPassword() -> String {
        Faker(locale: "en-US").internet.password(minimumLength: 5, maximumLength: 17)
    }
}

extension XCTest {

    func epic(_ values: String...) {
        label(name: "epic", values: values)
    }
    func feature(_ values: String...) {
        label(name: "feature", values: values)
    }
    func story(_ stories: String...) {
        label(name: "story", values: stories)
    }
    func label(_ name: String,_ values: [String]) {
        label(name: name, values: values)
    }
    func step(_ name: String, step: () -> Void) {
        XCTContext.runActivity(named: name) { _ in
            step()
        }
    }
    private func label(name: String, values: [String]) {
        for value in values {
            XCTContext.runActivity(named: "allure.label." + name + ":" + value, block: {_ in})
        }
    }
}
