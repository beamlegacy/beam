//
//  WebIndexingControllerTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 05/05/2022.
//

import XCTest
@testable import Beam

private class FakeClusteringManager: ClusteringManagerProtocol {
    func getIdAndParent(tabToIndex: TabIndexingInfo) -> (UUID?, UUID?) { (nil, nil) }
    func addPage(id: UUID, parentId: UUID?, value: TabIndexingInfo?) { }
    func addPage(id: UUID, parentId: UUID?, value: TabIndexingInfo?, newContent: String?) { }
}

private class FakeWebIndexControllerDelegate: WebIndexControllerDelegate {
    var expectations: [XCTestExpectation]
    init(expectations: [XCTestExpectation]) {
        self.expectations = expectations
    }

    func webIndexingController(_ controller: WebIndexingController, didIndexPageForURL url: URL) {
        let expectation = expectations.removeFirst()
        expectation.fulfill()
    }
}

class WebIndexingControllerTests: XCTestCase {

    var sut: WebIndexingController!
    var tab: BrowserTab!
    var webViewExpectation: XCTestExpectation!

    override func setUpWithError() throws {
        sut = WebIndexingController(clusteringManager: FakeClusteringManager())
        tab = BrowserTab(state: BeamState(), browsingTreeOrigin: nil, originMode: .web, note: nil)
    }

    override func tearDownWithError() throws {
    }
    func loadPage(title: String, content: String) {
        let htmlString = """
        <html>
          <head>
            <title>\(title)</title>
          </head>
          <body>
            <p>\(content)</p>
          </body>
        </html>
        """
        webViewExpectation = expectation(description: "Test page should load.")
        tab.webView.navigationDelegate = self
        _ = tab.webView.loadHTMLString(htmlString, baseURL: nil)
        wait(for: [webViewExpectation], timeout: 10)
    }

    func testTabDidNavigateShouldNotWait() throws {
        let url = URL(string: "http://abc.com/page")!
        loadPage(title: "Test page", content: "cool content")
        
        let indexExpection = expectation(description: "Test page should index")
        let delegate = FakeWebIndexControllerDelegate(expectations: [indexExpection])
        sut.delegate = delegate
        sut.tabDidNavigate(tab, toURL: url, originalRequestedURL: nil, shouldWaitForBetterContent: false, isLinkActivation: false, currentTab: nil)
        let currentNode =  tab.browsingTree.current
        XCTAssertEqual(currentNode?.url, "http://abc.com/page")
        XCTAssertEqual(currentNode?.score.textAmount, 0)
        wait(for: [indexExpection], timeout: 2)
        XCTAssertEqual(currentNode?.title, "Test page")
        XCTAssertEqual(currentNode?.score.textAmount, 21)
    }

    func testTabDidNavigateShouldWaitUninterupted() throws {
        let url = URL(string: "http://abc.com/page")!
        let url2 = URL(string: "http://abc.com/page2")!
        loadPage(title: "Test page", content: "cool content")

        let indexExpectation = expectation(description: "Test page should index")
        let indexExpectation2 = expectation(description: "Test page 2 should index")

        let delegate = FakeWebIndexControllerDelegate(expectations: [indexExpectation, indexExpectation2])
        sut.delegate = delegate
        sut.betterContentReadDelay = 0.0
        sut.tabDidNavigate(tab, toURL: url, originalRequestedURL: nil, shouldWaitForBetterContent: true, isLinkActivation: false, currentTab: nil)

        let root =  try XCTUnwrap(tab.browsingTree.root)
        let node0 = try XCTUnwrap(root.children[0])
        XCTAssertEqual(node0.url, "http://abc.com/page")
        XCTAssertEqual(node0.score.textAmount, 0)

        wait(for: [indexExpectation], timeout: 2) //here we wait for 1st indexing to complete
        XCTAssertEqual(node0.title, "Test page")
        XCTAssertEqual(node0.score.textAmount, 21)

        loadPage(title: "Test page 2", content: "super cool content")
        sut.tabDidNavigate(tab, toURL: url2, originalRequestedURL: nil, shouldWaitForBetterContent: false, isLinkActivation: false, currentTab: nil)
        let node1 = try XCTUnwrap(node0.children[0])
        XCTAssertEqual(node1.url, "http://abc.com/page2")
        XCTAssertEqual(node1.score.textAmount, 0)

        wait(for: [indexExpectation2], timeout: 2)
        XCTAssertEqual(node1.title, "Test page 2")
        XCTAssertEqual(node1.score.textAmount, 27)
    }

    func testTabDidNavigateShouldWaitInterupted() throws {
        let url = URL(string: "http://abc.com/page")!
        let url2 = URL(string: "http://abc.com/page2")!

        let indexExpectation = expectation(description: "Test page should index")
        let indexExpectation2 = expectation(description: "Test page 2 should index")
        let delegate = FakeWebIndexControllerDelegate(expectations: [indexExpectation, indexExpectation2])
        sut.delegate = delegate

        sut.betterContentReadDelay = 10_000 //here 1st indexing won't wait for delay and will be interrupted by second one
        loadPage(title: "Test page", content: "cool content")
        sut.tabDidNavigate(tab, toURL: url, originalRequestedURL: nil, shouldWaitForBetterContent: true, isLinkActivation: false, currentTab: nil)

        let root =  try XCTUnwrap(tab.browsingTree.root)
        let node0 = try XCTUnwrap(root.children[0])
        XCTAssertEqual(node0.url, "http://abc.com/page")
        XCTAssertEqual(node0.score.textAmount, 0)

        loadPage(title: "Test page 2", content: "super cool content")
        sut.tabDidNavigate(tab, toURL: url2, originalRequestedURL: nil, shouldWaitForBetterContent: false, isLinkActivation: false, currentTab: nil)
        let node1 = try XCTUnwrap(node0.children[0])
        XCTAssertEqual(node1.url, "http://abc.com/page2")
        XCTAssertEqual(node1.score.textAmount, 0)
        wait(for: [indexExpectation, indexExpectation2], timeout: 2)

        XCTAssertEqual(node0.title, "Test page")
        XCTAssertEqual(node1.title, "Test page 2")
        XCTAssertEqual(node0.score.textAmount, 21)
        XCTAssertEqual(node1.score.textAmount, 27)
    }
}

extension WebIndexingControllerTests: WKNavigationDelegate {
      func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewExpectation.fulfill()
    }
}
