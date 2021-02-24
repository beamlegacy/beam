import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif

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
}
