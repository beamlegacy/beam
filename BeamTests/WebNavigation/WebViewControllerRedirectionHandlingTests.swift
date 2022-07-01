//
//  WebViewControllerRedirectionHandlingTests.swift
//  BeamTests
//
//  Created by Remi Santos on 04/04/2022.
//

import XCTest
import MockHttpServer
import WebKit
@testable import Beam

/// Testing That WebViewController correctly receives navigation events after different redirection
class WebViewControllerRedirectionHandlingTests: XCTestCase {

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
        let JSHandler = JSNavigationMessageHandler() // adding JS handler to make sure it doesn't interfere.
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

    func testStraightForwardNavigation() {
        let expectation = expectation(description: "navigation_finished")
        var finalNavigationDescription: WebViewNavigationDescription?
        mockPage.onNavigationFinished = { navDescription in
            finalNavigationDescription = navDescription
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .none)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, initialURL)
        XCTAssertEqual(finalNavigationDescription?.url, initialURL)
        XCTAssertEqual(finalNavigationDescription?.requestedURL, initialURL)
    }

    func testRedirection301() {
        let expectation = expectation(description: "navigation_finished")
        var finalNavigationDescription: WebViewNavigationDescription?
        mockPage.onNavigationFinished = { navDescription in
            finalNavigationDescription = navDescription
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .http301)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(finalNavigationDescription?.url, destinationURL)
        XCTAssertEqual(finalNavigationDescription?.requestedURL, initialURL)
    }

    func testRedirection302() {
        let expectation = expectation(description: "navigation_finished")
        var finalNavigationDescription: WebViewNavigationDescription?
        mockPage.onNavigationFinished = { navDescription in
            finalNavigationDescription = navDescription
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .http302)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(finalNavigationDescription?.url, destinationURL)
        XCTAssertEqual(finalNavigationDescription?.requestedURL, initialURL)
    }

    func testHTMLRedirection() {
        let expectation = expectation(description: "navigation_finished")
        expectation.expectedFulfillmentCount = 2
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .html)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.requestedURL, initialURL)
    }

    func testJavascriptPushRedirection() {
        let expectation = expectation(description: "navigation_finished")
        expectation.expectedFulfillmentCount = 2
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .javascriptPush)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: 4, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        XCTAssertNil(receivedNavigationDescriptions.last?.requestedURL)
    }

    func testJavascriptPushSlowRedirection() {
        let expectation = expectation(description: "navigation_finished")
        expectation.expectedFulfillmentCount = 2
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .javascriptPushSlow)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        XCTAssertNil(receivedNavigationDescriptions.last?.requestedURL)
    }

    func testJavascriptReplaceRedirection() {
        let expectation = expectation(description: "navigation_finished")
        expectation.expectedFulfillmentCount = 2
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .javascriptReplace)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.requestedURL, initialURL)
    }

    func testJavascriptReplaceSlowRedirection() {
        let expectation = expectation(description: "navigation_finished")
        expectation.expectedFulfillmentCount = 2
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            expectation.fulfill()
        }

        let initialURL = redirectURL(for: .javascriptReplaceSlow)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        // a js replace happenning long after first load is not considered a redirection
        XCTAssertNil(receivedNavigationDescriptions.last?.requestedURL)
    }

}
