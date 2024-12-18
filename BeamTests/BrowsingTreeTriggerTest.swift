//
//  BrowsingTreeTriggerTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 12/05/2022.
//

import XCTest
import Nimble
@testable import BeamCore
@testable import Beam

class BrowsingTreeTriggerTests: WebBrowsingBaseTests {

    func testNavigation() throws {
        let url0 = "http://localhost:\(Configuration.MockHttpServer.port)/"

        let indexExpectations = (0...3).map { i in expectation(description: "index \(i)") }
        var indexExpectation = indexExpectations[0]
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }

        tab.load(request: URLRequest(url: URL(string: url0)!))
        wait(for: [indexExpectation], timeout: 1)
        var current = try XCTUnwrap(tab.browsingTree.current)
        let id0 = current.id
        XCTAssertEqual(current.url, url0)
        XCTAssertEqual(current.parent?.events.last?.type, .searchBarNavigation)

        indexExpectation = indexExpectations[1]
        let clickExpectation = expectation(description: "click")
        tab.webView.evaluateJavaScript("document.querySelector('ul li a').click();") { (_, _) in
            clickExpectation.fulfill()
        }
        wait(for: [clickExpectation], timeout: 1)
        wait(for: [indexExpectation], timeout: 10)
        current = try XCTUnwrap(tab.browsingTree.current)
        let id1 = current.id
        let url1 = current.url
        XCTAssertEqual(current.parent?.events.last?.type, .navigateToLink)

        indexExpectation = indexExpectations[2]
        tab.goBack()
        wait(for: [indexExpectation], timeout: 1)
        current = try XCTUnwrap(tab.browsingTree.current)
        XCTAssertEqual(current.id, id0)
        XCTAssertEqual(current.url, url0)
        XCTAssertEqual(current.children[0].events.last?.type, .exitBackward)

        indexExpectation = indexExpectations[3]
        tab.goForward()
        wait(for: [indexExpectation], timeout: 1)
        current = try XCTUnwrap(tab.browsingTree.current)
        XCTAssertEqual(current.id, id1)
        XCTAssertEqual(current.url, url1)
        XCTAssertEqual(current.parent?.events.last?.type, .exitForward)
    }
    func testNavigationWithRedirectFromOtherFrame() {
        //redirection from an iframe trigger navigation recording
        let url0 = "http://lvh.me:\(Configuration.MockHttpServer.port)/otherframe/index?topredirect=true"

        let indexExpectations = (0...1).map { i in expectation(description: "index \(i)") }
        var i = 0
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectations[i].fulfill()
            i += 1
        }
        tab.load(request: URLRequest(url: URL(string: url0)!))
        wait(for: indexExpectations, timeout: 1)
        XCTAssertEqual(tab.browsingTree.current.parent?.url, url0)
        XCTAssertEqual(tab.browsingTree.currentLink, "http://lvh.me:\(Configuration.MockHttpServer.port)/")
    }
    func testNavigationWithoutRedirectionFromOtherFrame() {
        //redirection within an iframe doesnt trigger navigation recording
        let url0 = "http://lvh.me:\(Configuration.MockHttpServer.port)/otherframe/index?topredirect=false"

        let indexExpectations = (0...1).map { i in expectation(description: "index \(i)") }
        var i = 0
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectations[i].fulfill()
            i += 1
        }
        tab.load(request: URLRequest(url: URL(string: url0)!))
        XCTExpectFailure("There should be only one indexing") {
            wait(for: indexExpectations, timeout: 1)
        }
        XCTAssertEqual(tab.browsingTree.currentLink, url0)
    }

    func testJsBackwardForward() {
        let url = "http://localhost:\(Configuration.MockHttpServer.port)/"
        let indexExpectations = (0...4).map { expectation(description: "page indexing \($0)") }
        var expectationIndex = 0
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectations[expectationIndex].fulfill()
            expectationIndex += 1
        }
        tab.load(request: URLRequest(url: URL(string: url)!))
        wait(for: [indexExpectations[0]], timeout: 1)
        let jsHistoryScript = """
        history.pushState({page: 1}, "", "?page=1");
        history.pushState({page: 2}, "", "?page=2");
        """
        let jsExpectation = expectation(description: "jsExpectation")
        tab.webView.evaluateJavaScript(jsHistoryScript) { (result, error) in
            jsExpectation.fulfill()
        }
        wait(for: [jsExpectation, indexExpectations[1], indexExpectations[2]], timeout: 1, enforceOrder: true)
        XCTAssertEqual(tab.browsingTree.currentLink, url + "?page=2")
        tab.goBack()
        expect(self.tab.browsingTree.currentLink).toEventually(equal(url + "?page=1"))
        XCTAssertEqual(tab.browsingTree.current.children.last?.events.last?.type, .exitBackward)
        tab.goForward()
        expect(self.tab.browsingTree.currentLink).toEventually(equal(url + "?page=2"))
        XCTAssertEqual(tab.browsingTree.current.parent?.events.last?.type, .exitForward)
        wait(for: [indexExpectations[3], indexExpectations[4]], timeout: 1, enforceOrder: true)
    }

    func testSwitchTo() {
        let indexExpectations = (0...1).map { i in expectation(description: "index \(i)") }
        var indexExpectation = indexExpectations[0]
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }

        let url0 = "http://localhost:\(Configuration.MockHttpServer.port)/"
        let request0 = URLRequest(url: URL(string: url0)!)
        //start reading when tab is current
        let tab0 = state.createTab(withURLRequest: request0, originalQuery: nil, setCurrent: true, note: nil, rootElement: nil, webView: nil)
        wait(for: [indexExpectation], timeout: 1)
        XCTAssertEqual(tab0.browsingTree.current.events.last?.type, .startReading)

        //and conversely not start reading when tab is not current
        indexExpectation = indexExpectations[1]
        let tab1 = state.createTab(withURLRequest: request0, originalQuery: nil, setCurrent: false, note: nil, rootElement: nil, webView: nil)
        wait(for: [indexExpectation], timeout: 1)
        XCTAssertEqual(tab1.browsingTree.current.events.last?.type, .creation)

        //switch to other tab test
        state.browserTabsManager.setCurrentTab(tab1)
        XCTAssertEqual(tab0.browsingTree.current.events.last?.type, .switchToOtherTab)
        XCTAssertEqual(tab1.browsingTree.current.events.last?.type, .startReading)

        //switch to background
        tab1.switchToBackground()
        XCTAssertEqual(tab1.browsingTree.current.events.last?.type, .switchToBackground)
        //switch to journal
        tab1.switchToJournal()
        XCTAssertEqual(tab1.browsingTree.current.events.last?.type, .switchToJournal)
        //switch to note
        tab1.switchToCard()
        XCTAssertEqual(tab1.browsingTree.current.events.last?.type, .switchToCard)
    }

    func testCloseApp() {
        let indexExpectation = expectation(description: "index 0")
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }

        let url = "http://localhost:\(Configuration.MockHttpServer.port)/"
        let request = URLRequest(url: URL(string: url)!)
        //start reading when tab is current
        let tab = state.createTab(withURLRequest: request, originalQuery: nil, setCurrent: true, note: nil, rootElement: nil, webView: nil)
        wait(for: [indexExpectation], timeout: 1)
        tab.appWillClose()
        XCTAssertEqual(tab.browsingTree.current.events.last?.type, .closeApp)
    }

    func testCloseTab() {
        let indexExpectation = expectation(description: "index 0")
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }

        let url = "http://localhost:\(Configuration.MockHttpServer.port)/"
        let request = URLRequest(url: URL(string: url)!)
        //start reading when tab is current
        let tab = state.createTab(withURLRequest: request, originalQuery: nil, setCurrent: true, note: nil, rootElement: nil, webView: nil)
        wait(for: [indexExpectation], timeout: 1)
        tab.tabWillClose()
        XCTAssertEqual(tab.browsingTree.current.events.last?.type, .closeTab)
    }

    private func getJSValue<T>(webView: WKWebView, script: String) -> T? {
        let expectation = expectation(description: "get JS value")
        var output: T?
        webView.evaluateJavaScript(script) { (result, _) in
            output = result as? T
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        return output
    }

    func testScrollRatio() throws {
        let indexExpectation = expectation(description: "index 0")
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }
        let scrollAmountX = 50
        let scrollAmountY = 100

        let url = "http://localhost:\(Configuration.MockHttpServer.port)/"
        let request = URLRequest(url: URL(string: url)!)
        //start reading when tab is current
        let tab = state.createTab(withURLRequest: request, originalQuery: nil, setCurrent: true, note: nil, rootElement: nil, webView: nil)
        wait(for: [indexExpectation], timeout: 1)

        let scrollHeight: Int = try XCTUnwrap(getJSValue(webView: tab.webView, script: "document.body.scrollHeight;"))
        let scrollWidth: Int = try XCTUnwrap(getJSValue(webView: tab.webView, script: "document.body.scrollWidth;"))

        //webpage scrolling simulation
        let scrollExpectation = expectation(description: "scroll")
        tab.webView.evaluateJavaScript("document.body.scrollTop = \(scrollAmountY); document.body.scrollLeft = \(scrollAmountX);") { (result, error) in
            scrollExpectation.fulfill()
        }
        wait(for: [scrollExpectation], timeout: 1)
        let expectetScrollRatioX = Float(scrollAmountX) / Float(scrollWidth)
        let expectetScrollRatioY = Float(scrollAmountY) / Float(scrollHeight)
        expect(tab.browsingTree.current.score.scrollRatioX).toEventually(equal(expectetScrollRatioX))
        expect(tab.browsingTree.current.score.scrollRatioY).toEventually(equal(expectetScrollRatioY))

    }

    func testCmdClick() throws {
        let url0 = "http://localhost:\(Configuration.MockHttpServer.port)/"
        let url1 = "http://ambiguous.form.lvh.me:\(Configuration.MockHttpServer.port)/"

        let indexExpectations = (0...1).map { i in expectation(description: "index \(i)") }
        var indexExpectation = indexExpectations[0]
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }
        let tab0 = state.createTab(withURLRequest: URLRequest(url: URL(string: url0)!))
        wait(for: [indexExpectation], timeout: 1)

        indexExpectation = indexExpectations[1]

// unfortunate attempt to simulate a cmd click using js
//        let clickExpectation = expectation(description: "click")
//        state.browserTabsManager.currentTab?.webView.evaluateJavaScript("document.querySelector('ul li a').dispatchEvent(new MouseEvent('click', {metaKey: true}));") { (_, _) in
//            clickExpectation.fulfill()
//        }
//        wait(for: [clickExpectation], timeout: 1)

        //lower level cmd click tab creation
        let tab1 = try XCTUnwrap(tab0.createNewTab(URLRequest(url: URL(string: url1)!), nil, setCurrent: false, rect: NSRect()) as? BrowserTab)
        wait(for: [indexExpectation], timeout: 1)

        XCTAssertEqual(tab0.browsingTree.current.events.last?.type, .openLinkInNewTab)
        XCTAssertEqual(tab1.browsingTree.current.url, url1)
        switch tab1.browsingTree.origin {
        case let .browsingNode(id: nodeId, pageLoadId: pageLoadId, rootOrigin: rootOrigin, rootId: rootId):
            XCTAssertEqual(nodeId, tab0.browsingTree.current.id)
            XCTAssertEqual(pageLoadId, tab0.browsingTree.current.events.last?.pageLoadId)
            XCTAssertEqual(rootOrigin, tab0.browsingTree.origin)
            XCTAssertEqual(rootId, tab0.browsingTree.rootId)
        default: XCTFail("Should be a browsing node origin")
        }
    }

    func testOrigins() throws {

        //trigger a searchBar origin
        let url = "http://localhost:\(Configuration.MockHttpServer.port)/"

        let indexExpectations = (0...3).map { i in expectation(description: "index \(i)") }
        var indexExpectation = indexExpectations[0]
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }
        //this tab acts as a reffering one
        let tab0 = state.createTab(withURLRequest: URLRequest(url: URL(string: url)!), setCurrent: true)
        wait(for: [indexExpectation], timeout: 1)

        indexExpectation = indexExpectations[1]
        let expectedQuery = "cat in a cardboard box"
        let tab1 = state.createTab(withURLRequest: URLRequest(url: URL(string: url)!), originalQuery: expectedQuery)
        wait(for: [indexExpectation], timeout: 1)

        switch tab1.browsingTree.origin {
        case let .searchBar(query: query, referringRootId: referringRootId):
            XCTAssertEqual(query, expectedQuery)
            XCTAssertEqual(referringRootId, tab0.browsingTree.rootId)
        default: XCTFail("Should be a search bar origin")
        }

        //search from node
        indexExpectation = indexExpectations[2]
        let expectedText = "hi there"
        let note = try BeamNote(title: "abc")
        note.owner = BeamData.shared.currentDatabase
        let editor = BeamTextEdit(root: note, journalMode: false, enableDelayedInit: false)
        editor.prepareRoot()
        let root = editor.rootNode!
        let node = TextNode(parent: root, element: BeamElement(expectedText), availableWidth: 0)
        root.addChild(node)

        state.createTabFromNode(node, withURL: URL(string: url)!)
        wait(for: [indexExpectation], timeout: 1)

        switch state.browserTabsManager.currentTab?.browsingTree.origin {
        case let .searchFromNode(nodeText: text):
            XCTAssertEqual(text, expectedText)
        default: XCTFail("Should be a search from node origin")
        }

        //click on link in note
        indexExpectation = indexExpectations[3]
        let expectedNoteTitle = "my note"
        let note2 = try BeamNote(title: expectedNoteTitle)
        note2.owner = BeamData.shared.currentDatabase
        let element = BeamElement("some text")
        state.handleOpenURLFromNote(URL(string: url)!, note: note2, element: element, inBackground: true)
        wait(for: [indexExpectation], timeout: 1)

        switch state.browserTabsManager.tabs.last?.browsingTree.origin {
        case let .linkFromNote(noteName: noteName):
            XCTAssertEqual(noteName, expectedNoteTitle)
        default: XCTFail("Should be a link from note origin")
        }
    }
}
