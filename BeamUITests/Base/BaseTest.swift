//
//  BaseTest.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

//Designed to be inherited by Test classes.
//It contains common setup and tear down methods as well as the common methods used in Test classes
class BaseTest: XCTestCase {

    let implicitWaitTimeout = TimeInterval(10)
    let minimumWaitTimeout = TimeInterval(2)
    let emptyString = ""
    let beamAppInstance = XCUIApplication(bundleIdentifier: "co.beamapp.macos")
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        super.tearDown()
        terminateAppInstance()
        storeScreenshot()
    }
    
    override func tearDown() {
        if isAppRunning() {
            UITestsMenuBar().destroyDB()
        }
        super.tearDown()
        terminateAppInstance()
    }
    
    func waitUntiAppIsNotRunning(timeout: TimeInterval = TimeInterval(2)) -> Bool {
        var count: TimeInterval = 0
        while isAppRunning() && count < timeout {
            sleep(1)
            count += 1
        }
        return count < timeout
    }

    private func storeScreenshot() {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    @discardableResult
    func launchApp() -> JournalTestView {
        XCUIApplication().launch()
        return JournalTestView()
    }
    
    func launchAppWithArgument(_ argument: String) {
        let app = XCUIApplication()
        app.launchArguments = [argument]
        app.launch()
    }
    
    @discardableResult
    func restartApp() -> JournalTestView {
        let app = XCUIApplication()
        app.terminate()
        app.launch()
        return JournalTestView()
    }
    
    func assertElementProperties(_ element: XCUIElement, _ isSelectedExpected: Bool, _ isEnabledExpected: Bool, _ isHittableExpected: Bool) {
        XCTAssertEqual(isSelectedExpected, element.isSelected)
        XCTAssertEqual(isEnabledExpected, element.isEnabled)
        XCTAssertEqual(isHittableExpected, element.isHittable)
    }
    
    @discardableResult
    func openFirstCardInAllCardsList() -> CardTestView {
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        return AllCardsTestView().openFirstCard()
    }
    
    func testRailPrint(_ text: String) { print(text) }
    
    func terminateAppInstance() {
        if isAppRunning() {
            beamAppInstance.terminate()
        }
    }
    
    func isAppRunning() -> Bool {
        return beamAppInstance.state != XCUIApplication.State.notRunning
    }
}
