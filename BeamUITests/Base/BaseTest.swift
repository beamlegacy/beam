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

    /// Default timeout of 20s
    static let implicitWaitTimeout = TimeInterval(10)
    /// Default minimum timeout of 2s
    static let minimumWaitTimeout = TimeInterval(2)
    let emptyString = ""
    let beamAppInstance = XCUIApplication(bundleIdentifier: "co.beamapp.macos")
    let uiTestModeLaunchArgument = "XCUITest"
    let correctEmail = "qa+autotestsignin@beamapp.co"
    let incorrectEmail = "qa+autotestsignin@beamappa.co"
    let correctPassword = "JKRZ6#ykhm_6KR!"
    let incorrectPassword = "Incorrect1"
    let username = "AutomationTestSignin"

    override func tearDownWithError() throws {
        super.tearDown()
        terminateAppInstance()
    }
    
    override func tearDown() {
        if isAppRunning() {
            storeScreenshot()
            UITestsMenuBar().destroyDB()
        }
        super.tearDown()
        terminateAppInstance()
    }
    
    func waitUntiAppIsNotRunningFor(timeout: TimeInterval = TimeInterval(5)) -> Bool {
        let now = NSTimeIntervalSince1970
        while isAppRunning() && NSTimeIntervalSince1970 < now + timeout {
            usleep(1000)
        }
        return isAppRunning()
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
    
    func launchAppWithArgument(_ argument: String) -> JournalTestView {
        let app = XCUIApplication()
        app.launchArguments = [argument]
        app.launch()
        return JournalTestView()
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

    func terminateAppInstance() {
        if isAppRunning() {
            beamAppInstance.terminate()
        }
    }
    
    func isAppRunning() -> Bool {
        return beamAppInstance.state != XCUIApplication.State.notRunning
    }
}
