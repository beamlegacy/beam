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

    /// Default timeout of 5s
    static let implicitWaitTimeout = TimeInterval(5)
    /// Default minimum timeout of 0.5s
    static let minimumWaitTimeout = TimeInterval(0.5)
    static let maximumWaitTimeout = TimeInterval(10)
    let emptyString = ""
    let beamAppInstance = XCUIApplication(bundleIdentifier: "co.beamapp.macos")
    let uiTestModeLaunchArgument = "XCUITest"
    let correctEmail = "qa+automationtest@beamapp.co"
    let correctEmailCamelCase = "qA+automAtiontest@beamapp.co"
    let incorrectEmail = "qa+automationtest@beamappa.co"
    let correctPassword = "JKRZ6#ykhm_6KR!"
    let correctEncKey = "8NwAtaGjtZCBcLvB6jPWbA4UwNiuIyHVe2CkbS2L0Tc="
    let incorrectPassword = "Incorrect1"
    let username = "AutomationTestSignin"
    let host = "form.lvh.me"
    let mockBaseUrl = "http://form.lvh.me:8080/"
    
    let uiMenu = UITestsMenuBar()
    let shortcutHelper = ShortcutsHelper()
    let mockPage = MockHTTPWebPages()
    let passwordManagerHelper = PasswordManagerHelper()
    var webView = WebTestView()
    
    var deletePK = false
    var deleteRemoteAccount = false

    override func tearDownWithError() throws {
        super.tearDown()
        terminateAppInstance()
    }
    
    override func tearDown() {
        if isAppRunning() {
            storeScreenshot()
            uiMenu.destroyDB()
        }
        if deletePK {
            uiMenu.deletePrivateKeys()
        }
        if deleteRemoteAccount {
            uiMenu.deleteRemoteAccount().resetAPIEndpoints()
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
        continueAfterFailure = false
        XCUIApplication().launch()
        return JournalTestView()
    }
    
    @discardableResult
    func launchAppWithArgument(_ argument: String) -> JournalTestView {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [argument]
        app.launch()
        return JournalTestView()
    }

    /// terminateImmediately means the app won't receive the proper termination events (aka applicationShouldTerminate),
    /// and therefore none of our sync or save mechanism will be triggered
    @discardableResult
    func restartApp(terminateImmediately: Bool = false) -> JournalTestView {
        let app = XCUIApplication()
        if !terminateImmediately {
            shortcutHelper.shortcutActionInvoke(action: .quitApp)
        } else {
            app.terminate()
        }
        app.launch()
        return JournalTestView()
    }
    
    func assertElementProperties(_ element: XCUIElement, _ isSelectedExpected: Bool, _ isEnabledExpected: Bool, _ isHittableExpected: Bool) {
        XCTAssertEqual(isSelectedExpected, element.isSelected)
        XCTAssertEqual(isEnabledExpected, element.isEnabled)
        XCTAssertEqual(isHittableExpected, element.isHittable)
    }
    
    @discardableResult
    func openFirstNoteInAllNotesList() -> NoteTestView {
        shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        return AllNotesTestView().openFirstNote()
    }

    func terminateAppInstance() {
        if isAppRunning() {
            beamAppInstance.terminate()
        }
    }
    
    func isAppRunning() -> Bool {
        return beamAppInstance.state != XCUIApplication.State.notRunning
    }
    
    @discardableResult
    func launchAppAndOpenFirstNote() -> NoteTestView {
        launchApp()
        shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        return AllNotesTestView().openFirstNote()
    }
    
    func isBigSurOS() -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return osVersion < 12
    }
    
    @discardableResult
    func setupStaging(withRandomAccount: Bool = false) -> JournalTestView {
        deleteRemoteAccount = true
        deletePK = true
        
        let journalView = launchAppWithArgument(uiTestModeLaunchArgument)
        
        uiMenu.setAPIEndpointsToStaging()
        if withRandomAccount {
            uiMenu.signUpWithRandomTestAccount()
        }
        return journalView
    }
}
