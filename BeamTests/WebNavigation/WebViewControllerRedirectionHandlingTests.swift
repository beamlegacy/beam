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
    private static let port: Int = 8080
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
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        let navigationExpectedCount = 2
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            if receivedNavigationDescriptions.count == navigationExpectedCount {
                expectation.fulfill()
            }
        }

        let initialURL = redirectURL(for: .html)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.requestedURL, nil)
    }

    func testJavascriptRedirection() {
        let expectation = expectation(description: "navigation_finished")
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        let navigationExpectedCount = 2
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            if receivedNavigationDescriptions.count == navigationExpectedCount {
                expectation.fulfill()
            }
        }

        let initialURL = redirectURL(for: .javascript)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.requestedURL, nil)
    }

    func testJavascriptReplaceRedirection() {
        let expectation = expectation(description: "navigation_finished")
        var receivedNavigationDescriptions = [WebViewNavigationDescription]()
        let navigationExpectedCount = 2
        mockPage.onNavigationFinished = { navDescription in
            receivedNavigationDescriptions.append(navDescription)
            if receivedNavigationDescriptions.count == navigationExpectedCount {
                expectation.fulfill()
            }
        }

        let initialURL = redirectURL(for: .javascriptReplace)
        sut.webViewIsInstructedToLoadURLFromUI(initialURL)
        webView.load(URLRequest(url: initialURL))

        waitForExpectations(timeout: navigationTimeout, handler: nil)

        XCTAssertEqual(webView.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.url, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.first?.requestedURL, initialURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.url, destinationURL)
        XCTAssertEqual(receivedNavigationDescriptions.last?.requestedURL, nil)
    }

}
