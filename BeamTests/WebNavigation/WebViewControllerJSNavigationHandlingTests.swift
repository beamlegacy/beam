//
//  WebViewControllerJSNavigationHandlingTests.swift
//  BeamTests
//
//  Created by Remi Santos on 04/04/2022.
//

import XCTest
import MockHttpServer
import WebKit
@testable import Beam

/**
 * Testing That WebViewController correctly receives JS navigation events.
 *
 * For each tests we prepare a dummy WebView and install the JS handler
 * We setup the WebViewController and see if they all work together when triggering navigation.
 */
class WebViewControllerJSNavigationHandlingTests: XCTestCase {

    var webView: WKWebView!
    var sut: WebViewController!
    private var mockPage: TestWebPageWithNavigation!
    private let navigationTimeout: TimeInterval = 4
    private static let port: Int = Configuration.MockHttpServer.port
    private var destinationURL: URL!

    override class func setUp() {
        MockHttpServer.start(port: port)
    }

    override class func tearDown() {
        MockHttpServer.stop(unregister: true)
    }

    override func setUp() {
        let JSHandler = JSNavigationMessageHandler()
        let configuration = BeamWebViewConfigurationBase(handlers: [JSHandler])
        webView = WKWebView(frame: .zero, configuration: configuration)
        destinationURL = redirectURL(for: .none)
        sut = WebViewController(with: webView)
        mockPage = TestWebPageWithNavigation(webViewController: sut)
        JSHandler.webPage = mockPage
    }

    private func redirectURL(for type: MockHttpServer.RedirectionType) -> URL {
        URL(string: MockHttpServer.redirectionURL(for: type, port: Self.port))!
    }

    private func performJSNavigation(to path: String, replace: Bool, completion: (() -> Void)?) {
        webView.evaluateJavaScript(MockHttpServer.navigationScriptToSimulateJSNavigation(for: path, replace: replace)) { _, _ in
            completion?()
        }
    }

    func testConsecutiveJSPushStateNavigation() {
        var expectation: XCTestExpectation?
        var lastNavigationDescription: WebViewNavigationDescription?
        var navigationFinishedCount = 0
        mockPage.onNavigationFinished = { navDescription in
            lastNavigationDescription = navDescription
            navigationFinishedCount += 1
            expectation?.fulfill()
        }

        // When I reach the first page
        let initialURL = redirectURL(for: .navigation)
        expectation = self.expectation(description: "navigation_finished1")
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive a regular navigation event
        XCTAssertEqual(webView.url, initialURL)
        XCTAssertEqual(lastNavigationDescription?.url, initialURL)
        XCTAssertEqual(lastNavigationDescription?.requestedURL, initialURL)

        // When I navigate with JS pushState
        expectation = self.expectation(description: "navigation_finished2")
        let jsExpectation = self.expectation(description: "jsExpectation")
        let url2 = "some2ndURL"
        performJSNavigation(to: url2, replace: false) {
            jsExpectation.fulfill()
        }

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive a navigation event
        XCTAssertEqual(lastNavigationDescription?.url.absoluteString.hasSuffix(url2), true)
        XCTAssertEqual(lastNavigationDescription?.source, WebViewControllerNavigationSource.javascript(replacing: false))
        XCTAssertEqual(lastNavigationDescription?.isLinkActivation, true)
        XCTAssertNil(lastNavigationDescription?.requestedURL)

        // When I navigate again with JS pushState
        expectation = self.expectation(description: "navigation_finished3")
        let jsExpectation2 = self.expectation(description: "jsExpectation2")
        let url3 = "anotherURL"
        performJSNavigation(to: url3, replace: false) {
            jsExpectation2.fulfill()
        }

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive another navigation event
        XCTAssertEqual(lastNavigationDescription?.url.absoluteString.hasSuffix(url3), true)
        XCTAssertEqual(lastNavigationDescription?.source, WebViewControllerNavigationSource.javascript(replacing: false))
        XCTAssertEqual(lastNavigationDescription?.isLinkActivation, true)
        XCTAssertNil(lastNavigationDescription?.requestedURL)

        XCTAssertEqual(navigationFinishedCount, 3)
    }


    func testConsecutiveJSReplaceStateNavigation() {
        var expectation: XCTestExpectation?
        var lastNavigationDescription: WebViewNavigationDescription?
        var navigationFinishedCount = 0
        mockPage.onNavigationFinished = { navDescription in
            lastNavigationDescription = navDescription
            navigationFinishedCount += 1
            expectation?.fulfill()
        }

        // When I reach the first page
        let initialURL = redirectURL(for: .navigation)
        expectation = self.expectation(description: "navigation_finished1")
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive a regular navigation event
        XCTAssertEqual(webView.url, initialURL)
        XCTAssertEqual(lastNavigationDescription?.url, initialURL)
        XCTAssertEqual(lastNavigationDescription?.requestedURL, initialURL)

        // When I navigate with JS pushState
        expectation = self.expectation(description: "navigation_finished2")
        let jsExpectation = self.expectation(description: "jsExpectation")
        let url2 = "some2ndURL"
        performJSNavigation(to: url2, replace: true) {
            jsExpectation.fulfill()
        }

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive a navigation event
        XCTAssertEqual(lastNavigationDescription?.url.absoluteString.hasSuffix(url2), true)
        XCTAssertEqual(lastNavigationDescription?.source, WebViewControllerNavigationSource.javascript(replacing: true))
        XCTAssertEqual(lastNavigationDescription?.isLinkActivation, false)
        XCTAssertEqual(lastNavigationDescription?.requestedURL, initialURL)

        // When I navigate again with JS replaceState
        expectation = self.expectation(description: "navigation_finished3")
        let jsExpectation2 = self.expectation(description: "jsExpectation2")
        let url3 = "anotherURL"
        performJSNavigation(to: url3, replace: true) {
            jsExpectation2.fulfill()
        }

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive another navigation event
        XCTAssertEqual(lastNavigationDescription?.url.absoluteString.hasSuffix(url3), true)
        XCTAssertEqual(lastNavigationDescription?.source, WebViewControllerNavigationSource.javascript(replacing: true))
        XCTAssertEqual(lastNavigationDescription?.isLinkActivation, false)
        XCTAssertEqual(lastNavigationDescription?.requestedURL, initialURL)

        XCTAssertEqual(navigationFinishedCount, 3)
    }

    func testJSAndBackForwardNavigation() throws {
        try XCTSkipIf(true, "Skip while we don't receive JS back/forward events BE-2045")
        var expectation: XCTestExpectation?
        var lastNavigationDescription: WebViewNavigationDescription?
        var navigationFinishedCount = 0
        mockPage.onNavigationFinished = { navDescription in
            lastNavigationDescription = navDescription
            navigationFinishedCount += 1
            expectation?.fulfill()
        }

        // When I reach the first page
        let initialURL = redirectURL(for: .navigation)
        expectation = self.expectation(description: "navigation_finished1")
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive a regular navigation event
        XCTAssertEqual(webView.url, initialURL)

        // When I navigate with JS pushState
        expectation = self.expectation(description: "navigation_finished2")
        let jsExpectation = self.expectation(description: "jsExpectation")
        let url2 = "some2ndURL"
        performJSNavigation(to: url2, replace: false) {
            jsExpectation.fulfill()
        }

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I receive a navigation event
        XCTAssertEqual(lastNavigationDescription?.url.absoluteString.hasSuffix(url2), true)
        XCTAssertEqual(webView.url?.absoluteString.hasSuffix(url2), true)

        // When I go back in history
        let backExpectation = self.expectation(description: "back_navigation")
        var lastNavigationWasForward: Bool?
        mockPage.onMoveInHistory = { forward in
            lastNavigationWasForward = forward
            backExpectation.fulfill()
        }
        webView.goBack()

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I received move back event
        XCTAssertEqual(lastNavigationWasForward, false)
        XCTAssertEqual(webView.url, initialURL)

        // When I go back in history
        let forwardExpectation = self.expectation(description: "back_navigation")
        mockPage.onMoveInHistory = { forward in
            lastNavigationWasForward = forward
            forwardExpectation.fulfill()
        }
        webView.goForward()

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        // Then I received move forward event
        XCTAssertEqual(lastNavigationWasForward, false)
        XCTAssertEqual(webView.url?.absoluteString.hasSuffix(url2), true)
    }

}
