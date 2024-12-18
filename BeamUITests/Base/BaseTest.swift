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
    let stagingEnvironmentServerAddress = "staging-web-server.ew.r.appspot.com"
    let tempURLToRedirectedReactNativeApp = "legendary-strudel.netlify.app"
    
    let uiTestPageOne = "Point And Shoot Test Fixture Ultralight Beam"
    let uiTestPageTwo = "Point And Shoot Test Fixture I-Beam"
    let uiTestPageThree = "Point And Shoot Test Fixture Cursor"
    let uiTestPageFour = "Point And Shoot Test Fixture Background image"
    
    let copyLinkShareAction = "Copy Link"
    
    let welcomeTourURL = "https://welcometour.beamapp.co"
    let meetingTestUrl = "https://zoom.us/wc/join/99166381562?wpk=wcpk3fe593748f47c7b9774ebde3650dae7d&_x_zm_rtaid=X_itykmcS52hw4BpB-NwCQ.1664430384941.f58312bdec889b861646d2e27f8794ea&_x_zm_rhtaid=711"
    
    let uiMenu = UITestsMenuBar()
    let hiddenCommand = HiddenCommandHelper()
    let hiddenNotification = HiddenNotificationHelper()
    let shortcutHelper = ShortcutsHelper()
    let mockPage = MockHTTPWebPages()
    let passwordManagerHelper = PasswordManagerHelper()
    var webView = WebTestView()
    var app = XCUIApplication()

    struct AccountInformation {
        let email: String
        let username: String
        let password: String
        let pk: String
    }
    
    override func tearDown() {
        uiMenu.invoke(.deleteRemoteAccount)
        if isAppRunning() {
            storeScreenshot()
        }
        uiMenu.invoke(.destroyDB)
        uiMenu.invoke(.deletePrivateKeys)
        self.clearPasteboard()
    }
    
    override func setUp() {
        launchApp()
    }
    
    func waitUntilAppIsNotRunningFor(timeout: TimeInterval = TimeInterval(5)) -> Bool {
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
        return launchAppWithArguments([uiTestModeLaunchArgument],
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
        hiddenCommand.resizeAndCenterAppForE2ETests()
        return JournalTestView()
    }
    
    @discardableResult
    func launchAndOpenAllNotes(signedIn: Bool = false) -> AllNotesTestView {
        launchApp().waitForJournalViewToLoad()
        if signedIn {
            uiMenu.invoke(.setAPIEndpointsToStaging)
            uiMenu.invoke(.signUpWithRandomTestAccount)
            _ = webView.waitForTabUrlAtIndexToEqual(index: 0, expectedString: welcomeTourURL)
        }
        shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        let allNotesView = AllNotesTestView()
        allNotesView.waitForAllNotesViewToLoad()
        return allNotesView
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
        args.append(contentsOf: [uiTestModeLaunchArgument])
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
    
    @discardableResult
    func deleteAllNotes() -> NoteTestView {
        hiddenCommand.deleteAllNotes()
    }
    
    func isAppRunning() -> Bool {
        return beamAppInstance.state != XCUIApplication.State.notRunning
    }
    
    @discardableResult
    func launchAppAndOpenTodayNote() -> NoteTestView {
        launchApp().waitForJournalViewToLoad()
        return openTodayNote()
    }
    
    func isBigSurOS() -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return osVersion < 12
    }
    
    @discardableResult
    func signUpStagingWithRandomAccount() -> JournalTestView {
        uiMenu.invoke(.signUpWithRandomTestAccount)
        let journalView = JournalTestView()
        journalView.waitForJournalViewToLoad()
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
    
    func getNumberOfTabGroupInWindowIndex(index: Int) -> Int {
        return app.windows.element(boundBy: index).groups.matching(TabGroupView().getAnyTabGroupPredicate()).count
    }
    
    func clearPasteboard() {
        NSPasteboard.general.clearContents()
        let pboard = NSPasteboard(name: .find)
        pboard.clearContents()
        pboard.setString("", forType: .string)
    }

    func captureGroupToNoteAndOpenNote() {
        let tabGroupView = TabGroupView()
        
        tabGroupView.captureTabGroup(index: 0)
        tabGroupView.closeTabGroup(index: 0)
        openTodayNote()
    }

    func testrailId(_ id: String) {
        print("TestRail scenario ID: \(id)")
    }
    
    func getNumberOfPasteboardItem() -> Int? {
        return NSPasteboard.general.pasteboardItems?.count
    }
    
    func getAppDialogs(dialogTitle: String) -> XCUIElement {
        return app.dialogs[dialogTitle]
    }
    
    func isPasteboardEmpty() -> Bool {
        return getNumberOfPasteboardItem() == 0
    }
    
    func moveMouseOutOfTheWay() {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).hover()
    }
    
    func createTabGroupAndSwitchToWeb(named: Bool = false) {
        if named {
            uiMenu.invoke(.createTabGroupNamed)
        } else {
            uiMenu.invoke(.createTabGroup)
        }
        shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        webView.waitForWebViewToLoad()
        TabGroupView().waitForTabGroupToBeDisplayed(index: 0)
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
    
    func signInWithoutPkKeyCheck(email: String, password: String) -> OnboardingImportDataTestView {
        let onboardingView = OnboardingLandingTestView()
        let onboardingUsernameView = OnboardingUsernameTestView()
        
        onboardingView.getEmailTextField().tapInTheMiddle()
        onboardingView.getEmailTextField().typeText(email)
        onboardingView.clickContinueWithEmailButton()
        
        onboardingUsernameView.getPasswordTextField().tapInTheMiddle()
        onboardingUsernameView.getPasswordTextField().typeText(password)
        onboardingUsernameView.typeKeyboardKey(.escape) //get rid of the pop-up window if exists
        onboardingUsernameView.clickConnectButton()
        return OnboardingImportDataTestView()
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

