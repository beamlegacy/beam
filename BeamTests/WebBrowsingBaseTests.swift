//
//  WebBrowsingBaseTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 12/05/2022.
//

import XCTest
import MockHttpServer
@testable import Beam
@testable import BeamCore

class WebBrowsingBaseTests: XCTestCase {

    var webView: WKWebView!
    var state: BeamState!
    var tab: BrowserTab!
    var mockIndexingDelegate: MockWebIndexingDelegate?
    var destinationURL: URL!
    static let port: Int = 8080

    let destinationPageTitle = "Redirection Destination"
    let jsDestinationPageTitle = "Redirected to destination"
    let defaultTimeout: TimeInterval = 2

    var linkStore: LinkStore {
        LinkStore.shared
    }

    override class func setUp() {
        MockHttpServer.start(port: port)
    }

    override class func tearDown() {
        MockHttpServer.stop(unregister: true)
    }

    override func setUp() {
        BeamObjectManager.disableSendingObjects = true

        linkStore.deleteAll(includedRemote: false, nil)
        webView = WKWebView()

        state = BeamState()
        state.data = BeamData()
        mockIndexingDelegate = MockWebIndexingDelegate()
        state.webIndexingController?.delegate = mockIndexingDelegate
        state.webIndexingController?.betterContentReadDelay = 0.2
        tab = BrowserTab(state: state, browsingTreeOrigin: .searchBar(query: "http", referringRootId: nil), originMode: .web, note: nil)

        destinationURL = redirectURL(for: .none)
    }

    func redirectURL(for type: MockHttpServer.RedirectionType) -> URL {
        URL(string: MockHttpServer.redirectionURL(for: type, port: Self.port))!
    }

    func simulateLinkNavigation(to type: MockHttpServer.RedirectionType, completion: (() -> Void)?) {
        tab.webView.evaluateJavaScript(MockHttpServer.redirectionScriptToSimulateLinkRedirection(for: type)) { _, _ in
            completion?()
        }
    }

    class MockWebIndexingDelegate: WebIndexControllerDelegate {

        var onIndexingFinished: ((URL) -> Void)?

        func webIndexingController(_ controller: WebIndexingController, didIndexPageForURL url: URL) {
            self.onIndexingFinished?(url)
        }

    }

}
