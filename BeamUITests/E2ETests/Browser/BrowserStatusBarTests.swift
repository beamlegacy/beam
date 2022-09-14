import Foundation
import XCTest

class BrowserStatusBarTests: BaseTest {

    func testShowStatusBar() throws {

        step("Given I open a web page"){
            launchApp()
            uiMenu.invoke(.resizeSquare1000)
                .invoke(.loadUITestPage1)
        }

        let link = webView.staticText("on Twitter")

        step("Given I enable the status bar"){
            uiMenu.menuItem("Show Status Bar").clickIfExists()
        }

        step("When hovering over a link"){
            link.hover()
        }

        let statusText = webView.statusText.getStringValue()

        step("Then the status bar must appear"){
            XCTAssertTrue(webView.statusText.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertEqual(statusText, "https://twitter.com/kanyewest/status/692435575836676097?lang=en")
        }

    }

    func testShowStatusBarForLinkOpeningInNewTab() throws {

        step("Given I open a web page"){
            launchApp()
            uiMenu.invoke(.loadUITestPage1)
        }
        
        let link = webView.staticText("new-tab-beam")
        step("Given I enable the status bar"){
            uiMenu.menuItem("Show Status Bar").clickIfExists()
        }

        step("When hovering over a link opening in a new tab"){
            link.hover()
        }

        let statusText = webView.statusText.getStringValue()

        step("Then the status bar must appear") {
            XCTAssertTrue(webView.statusText.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(statusText.hasPrefix(#"Open "file:///"#))
            XCTAssertTrue(statusText.hasSuffix(#".html" in a new tab"#))
        }

    }

    func testDisableStatusBar() {

        step("Given I open a web page"){
            launchApp()
            uiMenu.invoke(.loadUITestPage1)
        }

        let opensInNewTabLink = webView.staticText("new-tab-beam")
        step("Given I disable the status bar"){
            uiMenu.menuItem("Hide Status Bar").clickIfExists()
        }

        step("When hovering over a link"){
            opensInNewTabLink.hover()
        }

        step("Then the status bar must not appear"){
            XCTAssertFalse(webView.statusText.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
}
