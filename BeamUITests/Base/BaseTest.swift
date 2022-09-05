//
//  BaseTest.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest
import BeamCore
import Fakery

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
    let incorrectEmail = "qa+automationtest@beamappa.co"
    let incorrectPassword = "Incorrect1"
    let username = "AutomationTestSignin"
    let host = "form.lvh.me"
    let mockBaseUrl = "http://form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
    let stagingEnvironmentServerAddress = "staging-web-server.ew.r.appspot.com"
    
    let uiTestPageOne = "Point And Shoot Test Fixture Ultralight Beam"
    let uiTestPageTwo = "Point And Shoot Test Fixture I-Beam"
    let uiTestPageThree = "Point And Shoot Test Fixture Cursor"
    let uiTestPageFour = "Point And Shoot Test Fixture Background image"
    
    let copyLinkShareAction = "Copy Link"
    
    let uiMenu = UITestsMenuBar()
    let hiddenCommand = HiddenCommandHelper()
    let shortcutHelper = ShortcutsHelper()
    let mockPage = MockHTTPWebPages()
    let passwordManagerHelper = PasswordManagerHelper()
    var webView = WebTestView()
    var app = XCUIApplication()
    
    var deletePK = false
    var deleteRemoteAccount = false

    struct AccountInformation {
        let email: String
        let username: String
        let password: String
        let pk: String
    }

    override func tearDownWithError() throws {
        super.tearDown()
        terminateAppInstance()
    }
    
    override func tearDown() {
        if deleteRemoteAccount {
            uiMenu.deleteRemoteAccount().resetAPIEndpoints()
        }
        if isAppRunning() {
            storeScreenshot()
            uiMenu.destroyDB()
            sleep(1) //wait untill DB is destroyed to be used
        }
        if deletePK {
            uiMenu.deletePrivateKeys()
        }
        self.clearPasteboard()
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
    func launchApp(storeSessionWhenTerminated: Bool = false,
                   preventSessionRestore: Bool = false) -> JournalTestView {
        return launchAppWithArguments([],
                                      storeSessionWhenTerminated: storeSessionWhenTerminated,
                                      preventSessionRestore: preventSessionRestore)
    }
    
    @discardableResult
    func launchAppWithArgument(_ argument: String,
                               storeSessionWhenTerminated: Bool = false,
                               preventSessionRestore: Bool = false) -> JournalTestView {
        return launchAppWithArguments([argument],
                                      storeSessionWhenTerminated: storeSessionWhenTerminated,
                                      preventSessionRestore: preventSessionRestore)
    }

    @discardableResult
    func launchAppWithArguments(_ arguments: [String],
                                storeSessionWhenTerminated: Bool = false,
                                preventSessionRestore: Bool = false) -> JournalTestView {
        continueAfterFailure = false
        let app = XCUIApplication()
        var args: [String] = arguments
        args.append(contentsOf: ["-NSQuitAlwaysKeepsWindows", storeSessionWhenTerminated ? "1" : "0"])
        args.append(contentsOf: ["-WindowsRestorationPrevented", preventSessionRestore ? "1" : "0"])
        app.launchArguments = args
        app.launch()
        return JournalTestView()
    }

    /// terminateImmediately means the app won't receive the proper termination events (aka applicationShouldTerminate),
    /// and therefore none of our sync or save mechanism will be triggered
    @discardableResult
    func restartApp(terminateImmediately: Bool = false,
                    storeSessionWhenTerminated: Bool = false,
                    preventSessionRestore: Bool = false,
                    arguments: [String] = []) -> JournalTestView {
        let app = XCUIApplication()
        if !terminateImmediately {
            shortcutHelper.shortcutActionInvoke(action: .quitApp)
        } else {
            app.terminate()
        }
        let background = app.wait(for: .notRunning, timeout: 5)
        XCTAssertTrue(background)

        var args: [String] = arguments
        args.append(contentsOf: ["-NSQuitAlwaysKeepsWindows", storeSessionWhenTerminated ? "1" : "0"])
        args.append(contentsOf: ["-WindowsRestorationPrevented", preventSessionRestore ? "1" : "0"])
        app.launchArguments = args
        app.launch()
        return JournalTestView()
    }
    
    func assertElementProperties(_ element: XCUIElement, _ isSelectedExpected: Bool, _ isEnabledExpected: Bool, _ isHittableExpected: Bool) {
        XCTAssertEqual(isSelectedExpected, element.isSelected)
        XCTAssertEqual(isEnabledExpected, element.isEnabled)
        XCTAssertEqual(isHittableExpected, element.isHittable)
    }
    
    @discardableResult
    func openTodayNote() -> NoteTestView {
        hiddenCommand.openTodayNote()
    }

    @discardableResult
    func openNoteByTitle(_ title: String) -> NoteTestView {
        hiddenCommand.openNote(title: title)
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
    func launchAppAndOpenTodayNote() -> NoteTestView {
        launchApp()
        let noteView = openTodayNote()
        noteView.waitForNoteViewToLoad()
        return noteView
    }
    
    func isBigSurOS() -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return osVersion < 12
    }
    
    @discardableResult
    func setupStaging(withRandomAccount: Bool = false, waitingForWebViewToLoad: Bool = true) -> JournalTestView {
        deleteRemoteAccount = true
        deletePK = true
        
        let journalView = launchAppWithArgument(uiTestModeLaunchArgument)
        
        uiMenu.setAPIEndpointsToStaging()
        if withRandomAccount {
            uiMenu.signUpWithRandomTestAccount()
            if waitingForWebViewToLoad {
                webView.waitForWebViewToLoad()
            }
        }
        return journalView
    }

    func getCredentials() -> AccountInformation? {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .account)
        let accountView = AccountTestView()
        accountView.clickCopyAccountInfos()
        if let content = NSPasteboard.general.string(forType: .string) {
            let elements = content.components(separatedBy: "\n")
            return AccountInformation(email: elements[0], username: elements[1], password: elements[2], pk: elements[3])
        }
        return nil
    }
    
    func getRandomSearchTerm() -> String {
        Faker(locale: "en-US").commerce.color()
    }
    
    func getRandomEmail() -> String {
        Faker(locale: "en-US").internet.email()
    }
    
    func getRandomPassword() -> String {
        Faker(locale: "en-US").internet.password(minimumLength: 5, maximumLength: 17)
    }
    
    func getNumberOfWindows() -> Int {
        getWindowsQuery().count
    }

    func getWindowsQuery() -> XCUIElementQuery {
        self.app.windows
    }
    
    func getNumberOfTabInWindowIndex(index: Int) -> Int {
        return app.windows.element(boundBy: index).groups.matching(WebTestView().getAnyTabPredicate()).count
    }
    
    func clearPasteboard() {
        NSPasteboard.general.clearContents()
        let pboard = NSPasteboard(name: .find)
        pboard.clearContents()
        pboard.setString("", forType: .string)
    }

    func captureGroupToNoteAndOpenNote() {
        let tabGroupMenu = TabGroupMenuView()
        
        tabGroupMenu.waitForTabGroupToBeDisplayed(index: 0)
        tabGroupMenu.captureTabGroup(index: 0)
        tabGroupMenu.closeTabGroup(index: 0)
        openTodayNote()
    }

    func testrailId(_ id: String) {
        print("TestRail scenario ID: \(id)")
    }
    
    func getNumberOfPasteboardItem() -> Int? {
        return NSPasteboard.general.pasteboardItems?.count
    }
    
    func isPasteboardEmpty() -> Bool {
        return getNumberOfPasteboardItem() == 0
    }
    
    func moveMouseOutOfTheWay() {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).hover()
    }
    
    func typeAndEditHardcodedText (_ view: BaseView) -> String {
        view.app.typeText("Typed Text at the row")
        view.typeKeyboardKey(.leftArrow, 4)
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: 4)
        view.typeKeyboardKey(.delete)
        
        shortcutHelper.shortcutActionInvoke(action: .endOfLine)
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: 4)
        view.typeKeyboardKey(.delete)
        
        shortcutHelper.shortcutActionInvoke(action: .beginOfLine)
        view.typeKeyboardKey(.rightArrow, 4)
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectOnRight, numberOfTimes: 4)
        view.typeKeyboardKey(.space)
        let expectedTextAfterChange = "Type xt at"
        return expectedTextAfterChange
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

