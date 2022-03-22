import Foundation
import XCTest

class BrowserStatusBarTests: BaseTest {

    func testShowStatusBar() throws {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        helper.tapCommand(.resizeSquare1000)

        step("Given I open a web page"){
            helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        }

        let webView = WebTestView()
        let link = webView.staticText("on Twitter")

        step("Given I enable the status bar"){
            UITestsMenuBar().menuItem("Show Status Bar").clickIfExists()
        }

        step("When hovering over a link"){
            link.hover()
        }

        let statusText = webView.getElementStringValue(element:  webView.statusText)

        step("Then the status bar must appear"){
            XCTAssertTrue(webView.statusText.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertEqual(statusText, "https://twitter.com/kanyewest/status/692435575836676097?lang=en")
        }

    }

    func testShowStatusBarForLinkOpeningInNewTab() throws {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        step("Given I open a web page"){
            helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        }

        let webView = WebTestView()
        let link = webView.staticText("new-tab-beam")

        step("Given I enable the status bar"){
            UITestsMenuBar().menuItem("Show Status Bar").clickIfExists()
        }

        step("When hovering over a link opening in a new tab"){
            link.hover()
        }

        let statusText = webView.getElementStringValue(element:  webView.statusText)

        step("Then the status bar must appear") {
            XCTAssertTrue(webView.statusText.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(statusText.hasPrefix(#"Open "file:///"#))
            XCTAssertTrue(statusText.hasSuffix(#".html" in a new tab"#))
        }

    }

    func testDisableStatusBar() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        step("Given I open a web page"){
            helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        }

        let webView = WebTestView()
        let opensInNewTabLink = webView.staticText("new-tab-beam")

        step("Given I disable the status bar"){
            UITestsMenuBar().menuItem("Hide Status Bar").clickIfExists()
        }

        step("When hovering over a link"){
            opensInNewTabLink.hover()
        }

        step("Then the status bar must not appear"){
            XCTAssertFalse(webView.statusText.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
}
