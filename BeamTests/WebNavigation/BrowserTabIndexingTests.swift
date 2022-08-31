//
//  BrowserTabIndexingTests.swift
//  BeamTests
//
//  Created by Remi Santos on 04/04/2022.
//

import XCTest
import MockHttpServer
@testable import Beam
@testable import BeamCore

// Testing the navigation flow from the BrowserTab to the LinkStore
// to check what ends up in the indexing when doing different kind of navigation
class BrowserTabIndexingTests: WebBrowsingBaseTests {
    private func performAndTestAliasRedirection(ofType type: MockHttpServer.RedirectionType,
                                                expectedNumberOfIndexingCalls: Int,
                                                initialURLShouldBeAlias: Bool = true,
                                                destinationTitle: String) {
        let initialURL = redirectURL(for: type)

        let expectation = expectation(description: "done_indexing")
        expectation.expectedFulfillmentCount = expectedNumberOfIndexingCalls
        mockIndexingDelegate?.onIndexingFinished = { _ in
            expectation.fulfill()
        }
        tab.load(request: URLRequest(url: initialURL))

        waitForExpectations(timeout: defaultTimeout, handler: nil)

        XCTAssertEqual(tab.url, destinationURL)

        let allLinks = linkStore.allLinks
        XCTAssertTrue(allLinks.count > 0)

        let resultLinkForInitialURL = linkStore.getLinks(matchingUrl: initialURL.absoluteString).values.first
        XCTAssertEqual(resultLinkForInitialURL?.url, initialURL.absoluteString)

        let resultLinkForDestinationURL = linkStore.getLinks(matchingUrl: destinationURL.absoluteString).values.first
        XCTAssertEqual(resultLinkForDestinationURL?.url, destinationURL.absoluteString)
        XCTAssertEqual(resultLinkForDestinationURL?.title, destinationTitle)

        if initialURLShouldBeAlias {
            // the redirection is stored as an alias of the destination
            XCTAssertEqual(resultLinkForInitialURL?.destination, resultLinkForDestinationURL?.id)
            XCTAssertEqual(resultLinkForInitialURL?.title, destinationTitle)
        } else {
            // the redirection is NOT stored as an alias of the destination
            XCTAssertNil(resultLinkForInitialURL?.destination)
            XCTAssertNotEqual(resultLinkForInitialURL?.title, destinationTitle)
        }
    }
    func checkTree(redirectionType: MockHttpServer.RedirectionType, expectedNumberOfIndexingCalls: Int) {
        var currentNode = tab.browsingTree.root!
        if expectedNumberOfIndexingCalls == 2 {
            currentNode = currentNode.children[0]
            XCTAssertEqual(currentNode.url, redirectURL(for: redirectionType).absoluteString) //intermediate node
        }
        currentNode = currentNode.children[0]
        XCTAssertEqual(currentNode.url, redirectURL(for: .none).absoluteString)
    }

    func testHTTP301RedirectionIsStoredAsAlias() {
        let redirectionType: MockHttpServer.RedirectionType = .http301
        let expectedNumberOfIndexingCalls = 1
        performAndTestAliasRedirection(ofType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls, destinationTitle: destinationPageTitle)
        checkTree(redirectionType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls)
    }

    func testHTTP302RedirectionIsStoredAsAlias() {
        let redirectionType: MockHttpServer.RedirectionType = .http302
        let expectedNumberOfIndexingCalls = 1
        performAndTestAliasRedirection(ofType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls, destinationTitle: destinationPageTitle)
        checkTree(redirectionType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls)
    }

    func testHTMLRedirectionIsStoredAsAlias() {
        let redirectionType: MockHttpServer.RedirectionType = .html
        let expectedNumberOfIndexingCalls = 2
        performAndTestAliasRedirection(ofType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls, destinationTitle: destinationPageTitle)
        checkTree(redirectionType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls)
    }

    func testJavascriptPushRedirectionIsNOTStoredAsAlias() {
        let redirectionType: MockHttpServer.RedirectionType = .javascriptPush
        let expectedNumberOfIndexingCalls = 2
        performAndTestAliasRedirection(ofType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls,
                                       initialURLShouldBeAlias: false, destinationTitle: jsDestinationPageTitle)
        checkTree(redirectionType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls)
    }

    func testJavascriptReplaceRedirectionIsStoredAsAlias() {
        let redirectionType: MockHttpServer.RedirectionType = .javascriptReplace
        let expectedNumberOfIndexingCalls = 2
        performAndTestAliasRedirection(ofType: redirectionType, expectedNumberOfIndexingCalls: expectedNumberOfIndexingCalls,
                                       destinationTitle: jsDestinationPageTitle)
        let currentNode = tab.browsingTree.root!
        XCTAssertEqual(currentNode.children.count, 2)
        XCTAssertEqual(currentNode.children[0].url, redirectURL(for: redirectionType).absoluteString)
        XCTAssertEqual(currentNode.children[1].url, redirectURL(for: .none).absoluteString)
    }

    func testConsecutiveRedirectionsSeparatedByUILoads() {

        var expectation: XCTestExpectation?
        mockIndexingDelegate?.onIndexingFinished = { _ in
            expectation?.fulfill()
        }

        expectation = self.expectation(description: "done_indexingURL1")
        let initialURL1 = redirectURL(for: .http301)
        tab.load(request: URLRequest(url: initialURL1))
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        XCTAssertEqual(tab.url, destinationURL)

        expectation = self.expectation(description: "done_indexingURL2")
        let initialURL2 = redirectURL(for: .http302)
        tab.load(request: URLRequest(url: initialURL2))
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        XCTAssertEqual(tab.url, destinationURL)

        let allLinks = linkStore.allLinks
        XCTAssertTrue(allLinks.count > 0)

        let resultLinkForInitialURL1 = linkStore.getLinks(matchingUrl: initialURL1.absoluteString).values.first
        XCTAssertEqual(resultLinkForInitialURL1?.url, initialURL1.absoluteString)
        let resultLinkForInitialURL2 = linkStore.getLinks(matchingUrl: initialURL2.absoluteString).values.first
        XCTAssertEqual(resultLinkForInitialURL2?.url, initialURL2.absoluteString)

        let resultLinkForDestinationURL = linkStore.getLinks(matchingUrl: destinationURL.absoluteString).values.first
        XCTAssertEqual(resultLinkForDestinationURL?.title, destinationPageTitle)
        XCTAssertEqual(resultLinkForDestinationURL?.url, destinationURL.absoluteString)

        // the http redirections are stored as an alias of the destination
        XCTAssertEqual(resultLinkForInitialURL1?.destination, resultLinkForDestinationURL?.id)
        XCTAssertEqual(resultLinkForInitialURL1?.title, destinationPageTitle)
        XCTAssertEqual(resultLinkForInitialURL2?.destination, resultLinkForDestinationURL?.id)
        XCTAssertEqual(resultLinkForInitialURL1?.title, destinationPageTitle)

    }

    func testConsecutiveRedirectionsSeparatedByLinkClick() {

        var indexedURLs = [URL]()
        var expectation: XCTestExpectation?
        mockIndexingDelegate?.onIndexingFinished = { url in
            indexedURLs.append(url)
            expectation?.fulfill()
        }

        let initialURL1 = redirectURL(for: .http301)
        expectation = self.expectation(description: "done_indexing1")
        tab.load(request: URLRequest(url: initialURL1))
        waitForExpectations(timeout: defaultTimeout, handler: nil)
        XCTAssertEqual(tab.url, destinationURL)

        expectation = self.expectation(description: "done_indexing2")
        let linkExpectation = self.expectation(description: "jsExpectation")
        let linkType = MockHttpServer.RedirectionType.http302
        simulateLinkNavigation(to: linkType) {
            linkExpectation.fulfill()
        }

        waitForExpectations(timeout: defaultTimeout, handler: nil)

        XCTAssertEqual(indexedURLs, [destinationURL, destinationURL])
        let allLinks = linkStore.allLinks
        XCTAssertTrue(allLinks.count > 0)

        let resultLinkForInitialURL1 = linkStore.getLinks(matchingUrl: initialURL1.absoluteString).values.first
        XCTAssertEqual(resultLinkForInitialURL1?.url, initialURL1.absoluteString)

        let resultLinkForDestinationURL = linkStore.getLinks(matchingUrl: destinationURL.absoluteString).values.first
        XCTAssertEqual(resultLinkForDestinationURL?.url, destinationURL.absoluteString)
        XCTAssertEqual(resultLinkForDestinationURL?.title, destinationPageTitle)

        // the http redirection is stored as an alias of the destination
        XCTAssertEqual(resultLinkForInitialURL1?.destination, resultLinkForDestinationURL?.id)
        XCTAssertEqual(resultLinkForInitialURL1?.title, destinationPageTitle)

        // the second navigation is a click navigation, the webview goes directly to the destination so the intermediate is not indexed.
        let linkURL2 = redirectURL(for: linkType)
        let resultLinkForLinkURL2 = linkStore.getLinks(matchingUrl: linkURL2.absoluteString).values.first
        XCTAssertNil(resultLinkForLinkURL2)
    }
    func testYoutubeRedirect() {
        //simulate clicking on a video while the page is still loading
        //it should not lead to an aliased link.
        var expectation: XCTestExpectation?
        mockIndexingDelegate?.onIndexingFinished = { _ in
            expectation?.fulfill()
        }

        expectation = self.expectation(description: "done_indexing")
        let requestedUrl = URL(string: "http://lvh.me:\(Configuration.MockHttpServer.port)/redirection/youtube")!
        let finalUrl = URL(string: "http://lvh.me:\(Configuration.MockHttpServer.port)/youtube_redirected")!
        tab.load(request: URLRequest(url: requestedUrl))
        waitForExpectations(timeout: 10, handler: nil)

        let allLinks = linkStore.allLinks
        XCTAssertEqual(allLinks.count, 2)

        let resultLinkForRequestedUrl = linkStore.getLinks(matchingUrl: requestedUrl.absoluteString)
        XCTAssertEqual(resultLinkForRequestedUrl.count, 0)
        let resultLinkForFinalUrl = linkStore.getLinks(matchingUrl: finalUrl.absoluteString).values.first
        XCTAssertNil(resultLinkForFinalUrl?.destination)
    }

    private func activateLinkById(id: String) {
        let clickExpectation = expectation(description: "click on \(id)")
        tab.webView.evaluateJavaScript("document.getElementById('\(id)').click();") { (_, _) in
            clickExpectation.fulfill()
        }
        wait(for: [clickExpectation], timeout: 1)
    }

    func testNoAliasingWhenNewTab() throws {
        let indexExpectations = (0...2).map { i in expectation(description: "index \(i)") }
        var indexExpectation = indexExpectations[0]
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }
        let url0 = "http://lvh.me:\(Configuration.MockHttpServer.port)/redirection/new_tab"
        tab.load(request: URLRequest(url: URL(string: url0)!))
        wait(for: [indexExpectation], timeout: 1)

        //opens in a new tab
        indexExpectation = indexExpectations[1]
        activateLinkById(id: "sign_in")
        wait(for: [indexExpectation], timeout: 1)

        //then click on a link of url0
        indexExpectation = indexExpectations[2]
        activateLinkById(id: "back_home")
        wait(for: [indexExpectation], timeout: 1)

        //no alias from sign_in to back_home should be created
        let link = try XCTUnwrap(linkStore.getLinks(matchingUrl: "http://signin.form.lvh.me:\(Configuration.MockHttpServer.port)").values.first)
        XCTAssertNil(link.destination)
    }
}
