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

    init(_ app: XCUIApplication) {
        self.app = app
    }

    func tapCommand(_ command: UITestMenuAvailableCommands) {
        UITestMenuAvailableCommands.allCases.forEach {
            if $0 == command {
                let menu = XCUIApplication().menuItems[$0.rawValue]
                menu.tap()
                moveMouseOutOfTheWay()
                return
            }
        }
    }

    func moveMouseOutOfTheWay() {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).hover()
    }

    enum UITestsPageCommand {
        case page1
        case page2
        case page3
        case page4
        case password
        case alerts
        case media
    }

    func openTestPage(page: UITestsPageCommand) {
        switch page {
        case .page1:
            tapCommand(.loadUITestPage1)
        case .page2:
            tapCommand(.loadUITestPage2)
        case .page3:
            tapCommand(.loadUITestPage3)
        case .page4:
            tapCommand(.loadUITestPage4)
        case .password:
            tapCommand(.loadUITestPagePassword)
        case .alerts:
            tapCommand(.loadUITestPageAlerts)
        case .media:
            tapCommand(.loadUITestPageMedia)
        }
        
        let centerOfPage = self.app.webViews.element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        centerOfPage.hover()
    }

    func showLogs() {
        let menu = XCUIApplication().menuItems["Show Logs"]
        menu.tap()
    }

    func showJournal() {
        ShortcutsHelper().shortcutActionInvoke(action: .showJournal)
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

    func todayDate() -> String {
        return BeamDate.journalNoteTitle()
    }
    
    func addNote(noteTitle: String? = nil) {
        let notePickerField = self.app.textFields[todayDate()].firstMatch
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
