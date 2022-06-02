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

        var currentNode = tab.browsingTree.root!
        if expectedNumberOfIndexingCalls == 2 {
            currentNode = currentNode.children[0]
            XCTAssertEqual(currentNode.url, redirectURL(for: type).absoluteString) //intermediate node
        }
        currentNode = currentNode.children[0]
        XCTAssertEqual(currentNode.url, redirectURL(for: .none).absoluteString)
    }

    func testHTTP301RedirectionIsStoredAsAlias() {
        performAndTestAliasRedirection(ofType: .http301, expectedNumberOfIndexingCalls: 1, destinationTitle: destinationPageTitle)
    }

    func testHTTP302RedirectionIsStoredAsAlias() {
        performAndTestAliasRedirection(ofType: .http302, expectedNumberOfIndexingCalls: 1, destinationTitle: destinationPageTitle)
    }

    func testHTMLRedirectionIsStoredAsAlias() {
        performAndTestAliasRedirection(ofType: .html, expectedNumberOfIndexingCalls: 2, destinationTitle: destinationPageTitle)
    }

    func testJavascriptPushRedirectionIsNOTStoredAsAlias() {
        performAndTestAliasRedirection(ofType: .javascriptPush, expectedNumberOfIndexingCalls: 2,
                                       initialURLShouldBeAlias: false,
                                       destinationTitle: jsDestinationPageTitle)
    }

    func testJavascriptReplaceRedirectionIsStoredAsAlias() {
        performAndTestAliasRedirection(ofType: .javascriptReplace, expectedNumberOfIndexingCalls: 2, destinationTitle: jsDestinationPageTitle)
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


}
