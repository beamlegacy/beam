import Foundation
import XCTest

class BrowserStatusBarTests: BaseTest {

    func testShowStatusBar() throws {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        helper.tapCommand(.resizeSquare1000)

        testRailPrint("Given I open a web page")
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)

        let webView = WebTestView()
        let link = webView.staticText("on Twitter")

        testRailPrint("Given I enable the status bar")
        UITestsMenuBar().menuItem("Show Status Bar").clickIfExists()

        testRailPrint("When hovering over a link")
        link.hover()

        testRailPrint("Then the status bar must appear")
        XCTAssertTrue(webView.statusText.waitForExistence(timeout: implicitWaitTimeout))
        let statusText = try XCTUnwrap(webView.statusText.value as? String)
        XCTAssertEqual(statusText, "https://twitter.com/kanyewest/status/692435575836676097?lang=en")
    }

    func testShowStatusBarForLinkOpeningInNewTab() throws {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        testRailPrint("Given I open a web page")
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)

        let webView = WebTestView()
        let link = webView.staticText("new-tab-beam")

        testRailPrint("Given I enable the status bar")
        UITestsMenuBar().menuItem("Show Status Bar").clickIfExists()

        testRailPrint("When hovering over a link opening in a new tab")
        link.hover()

        testRailPrint("Then the status bar must appear")
        XCTAssertTrue(webView.statusText.waitForExistence(timeout: implicitWaitTimeout))
        let statusText = try XCTUnwrap(webView.statusText.value as? String)
        XCTAssertTrue(statusText.hasPrefix(#"Open "file:///"#))
        XCTAssertTrue(statusText.hasSuffix(#".html" in a new tab"#))
    }

    func testDisableStatusBar() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        testRailPrint("Given I open a web page")
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)

        let webView = WebTestView()
        let opensInNewTabLink = webView.staticText("new-tab-beam")

        testRailPrint("Given I disable the status bar")
        UITestsMenuBar().menuItem("Hide Status Bar").clickIfExists()

        testRailPrint("When hovering over a link")
        opensInNewTabLink.hover()

        testRailPrint("Then the status bar must not appear")
        XCTAssertFalse(webView.statusText.waitForExistence(timeout: minimumWaitTimeout))
    }
    
}
