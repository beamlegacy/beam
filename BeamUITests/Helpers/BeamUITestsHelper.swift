import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
import Fakery

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

    init(_ app: XCUIApplication) {
        self.app = app
    }

    func restart() {
        self.app.terminate()
        self.app.launch()
    }

    func tapCommand(_ command: MenuAvailableCommands) {
        MenuAvailableCommands.allCases.forEach {
            if $0 == command {
                let menu = XCUIApplication().menuItems[$0.rawValue]
                menu.tap()
                return
            }
        }
    }

    func showLogs() {
        let menu = XCUIApplication().menuItems["Show Logs"]
        menu.tap()
    }

    func showJournal() {
        self.app.typeKey("H", modifierFlags: [.command, .shift])
    }

    // Doesn't work 
    func logsValue() -> String? {
        let allLogsWindow = XCUIApplication().windows["All Logs"]
        allLogsWindow.click()
        return allLogsWindow.scrollViews.containing(.button, identifier: "Bottom").element.value as? String
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
    
    func addNote(noteTitle: String? = nil) {
        let notePickerField = self.app.textFields["Today"].firstMatch
        notePickerField.tap()
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
    
    func assertFramePositions(searchText: String, identifier: String) {
        let padding: CGFloat = 16
        let message = "\(identifier) location doesn't match \"\(searchText)\" location"
        // Delay because of animations
        sleep(1)
        // Hover element to make it active
        let referenceElementMiddle = self.app.webViews.staticTexts[searchText].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        referenceElementMiddle.hover()
        // Expect single element to be correctly displayed
        let PnsFrames = self.app.otherElements.matching(identifier: identifier)
        XCTAssertEqual(PnsFrames.count, 1)
        // Expect element to be correctly positioned
        let PnsFrame = self.app.otherElements.matching(identifier: identifier).element.frame
        let referenceElement = self.app.webViews.staticTexts[searchText].frame
        XCTAssertEqual(PnsFrame.origin.x, referenceElement.origin.x, accuracy: 10, message)
        XCTAssertEqual(PnsFrame.origin.y, referenceElement.origin.y, accuracy: 10, message)
        XCTAssertEqual(PnsFrame.width, referenceElement.width + padding, accuracy: 10, message)
        XCTAssertEqual(PnsFrame.height, referenceElement.height + padding, accuracy: 10, message)
    }
}


extension BeamUITestsHelper {
    func randomSearchTerm() -> String {
        Faker(locale: "en-US").commerce.color()
    }
}
