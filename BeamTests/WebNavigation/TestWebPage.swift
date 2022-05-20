//
//  TestWebPage.swift
//  BeamTests
//
//  Created by Remi Santos on 08/04/2022.
//

import XCTest
import Promises

@testable import Beam
@testable import BeamCore

class TestWebPage: WebPage {
    var events: [String] = []
    private(set) var originalQuery: String?
    private(set) var pointAndShootInstalled: Bool = true
    private(set) var pointAndShootEnabled: Bool = true
    private(set) var title: String = "PNS MockPage"
    static let urlStr = "https://webpage.com"
    var url: URL? = URL(string: urlStr)
    var score: Float = 0
    var pointAndShoot: PointAndShoot?
    var webFrames: WebFrames?
    var webPositions: WebPositions?
    var browsingScorer: BrowsingScorer?
    var storage: BeamFileStorage?
    var webAutofillController: WebAutofillController?
    var errorPageManager: ErrorPageManager?
    private(set) var webviewWindow: NSWindow?
    private(set) var frame: NSRect = NSRect(x: 0, y: 0, width: 600, height: 800)
    private(set) var mouseLocation: NSPoint!
    private(set) var downloadManager: DownloadManager?
    private(set) var webViewNavigationHandler: WebViewNavigationHandler?
    var hasError: Bool = false
    var responseStatusCode: Int = 200
    var mediaPlayerController: MediaPlayerController?
    var webView: BeamWebView
    var activeNote: BeamNote {
        if let note = testNotes.values.first {
            return note
        } else {
            return BeamNote(title: "activeNote backup")
        }
    }
    var testNotes: [String: BeamCore.BeamNote] = ["Note A": BeamNote(title: "Note A")]
    var fileStorage: BeamFileStorage? {
        storage
    }
    var contentDescription: BrowserContentDescription?
    var authenticationViewModel: AuthenticationViewModel?
    var searchViewModel: SearchViewModel?
    var mouseHoveringLocation: MouseHoveringLocation = .none

    init(browsingScorer: BrowsingScorer?, passwordOverlayController: WebAutofillController?, pns: PointAndShoot?,
         fileStorage: BeamFileStorage?, downloadManager: DownloadManager?, navigationHandler: WebViewNavigationHandler?) {
        self.browsingScorer = browsingScorer
        self.webAutofillController = passwordOverlayController
        pointAndShoot = pns
        storage = fileStorage
        self.downloadManager = downloadManager
        self.webViewNavigationHandler = navigationHandler
        self.webView = BeamWebView()
        let webFrames = WebFrames()
        self.webFrames = webFrames
        self.webPositions = WebPositions(webFrames: webFrames)
        contentDescription = WebContentDescription(webView: webView)
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addCSS \(source.hashValue) \(String(describing: when))")
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addJS \(source.hashValue) \(String(describing: when))")
    }

    func createNewTab(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, rect: NSRect) -> WebPage? {
        events.append("createNewTab \(request.url) \(setCurrent))")
        return TestWebPage(browsingScorer: browsingScorer, passwordOverlayController: webAutofillController, pns: pointAndShoot,
                           fileStorage: storage, downloadManager: downloadManager, navigationHandler: webViewNavigationHandler)
    }

    func createNewWindow(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        events.append("createNewWindow \(request.url) \(setCurrent))")
        let webPage = TestWebPage(browsingScorer: browsingScorer, passwordOverlayController: webAutofillController, pns: pointAndShoot,
                                  fileStorage: storage, downloadManager: downloadManager, navigationHandler: webViewNavigationHandler)

        return webPage.webView
    }

    func isActiveTab() -> Bool {
        true
    }

    func leave() {
        events.append("leave")
    }

    func shouldNavigateInANewTab(url: URL) -> Bool { false }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?> {
        if objectName == "PointAndShoot" {
            Logger.shared.logDebug("no matching jsCode case, no js call mocked", category: .pointAndShoot)
        }
        events.append("executeJS \(objectName ?? "").\(jsCode)")
        return Promise(true)
    }

    func logInNote(url: URL, reason: NoteElementAddReason) {
        events.append("logInNote \(url) \(reason)")
    }

    func addContent(content: [BeamElement], with source: URL? = nil, reason: NoteElementAddReason) {
        let sourceURL = source?.absoluteString ?? ""
        events.append("addContent \(sourceURL)")
    }

    func tabWillClose() {
        events.append("closeTab")
    }

    func setDestinationNote(_ note: BeamCore.BeamNote, rootElement: BeamCore.BeamElement?) {
        events.append("setDestinationNote \(note.title) \(String(describing: rootElement))")
    }

    func getNote(fromTitle: String) -> BeamCore.BeamNote? {
        events.append("getNote \(fromTitle)")
        return testNotes[fromTitle] ?? nil
    }

    func addTextToClusteringManager(_ text: String, url: URL) {}
}

// MARK: - WebViewControllerDelegate
class TestWebPageWithNavigation: TestWebPage, WebViewControllerDelegate {
    var onNavigationFinished: ((WebViewNavigationDescription) -> Void)?
    var onMoveInHistory: ((Bool) -> Void)?

    convenience init(webViewController: WebViewController?) {
        self.init(browsingScorer: nil, passwordOverlayController: nil, pns: nil, fileStorage: nil, downloadManager: nil, navigationHandler: webViewController)
        webViewController?.delegate = self
        webViewController?.page = self
    }

    // MARK: WebViewControllerDelegate
    func webViewController(_ controller: WebViewController, didFinishNavigatingToPage navigationDescription: WebViewNavigationDescription) {
        onNavigationFinished?(navigationDescription)
    }

    func webViewController<Value>(_ controller: WebViewController, observedValueChangedFor keyPath: KeyPath<WKWebView, Value>, value: Value) { }
    func webViewController(_ controller: WebViewController, didChangeDisplayURL url: URL) { }
    func webViewController(_ controller: WebViewController, willMoveInHistory forward: Bool) {
        onMoveInHistory?(forward)
    }
    func webViewControllerIsNavigatingToANewPage(_ controller: WebViewController) { }
    func webViewController(_ controller: WebViewController, didChangeLoadedContentType contentDescription: BrowserContentDescription?) { }
    }
