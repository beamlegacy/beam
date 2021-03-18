//
//  BrowserTab.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//
// swiftlint:disable file_length

import Foundation
import SwiftUI
import Combine
import WebKit

class FullScreenWKWebView: WKWebView {
//    override var safeAreaInsets: NSEdgeInsets {
//        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    }

    //Catching those event to avoid funk sound
    override func keyDown(with event: NSEvent) {
        if let key = event.specialKey {
            if key == .leftArrow || key == .rightArrow {
                return
            }
        }
        super.keyDown(with: event)
    }
}

// swiftlint:disable:next type_body_length
class BrowserTab: NSView, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, Codable {
    var id: UUID

    public func load(url: URL) {
        self.url = url
        navigationCount = 0
        webView.load(URLRequest(url: url))
    }

    @Published public var webView: WKWebView! {
        didSet {
            setupObservers()
        }
    }

    @Published var title: String = ""
    @Published var originalQuery: String?
    @Published var url: URL?
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false
    @Published var serverTrust: SecTrust?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList!
    @Published var visitedURLs = Set<URL>()
    @Published var favIcon: NSImage?

    @Published var browsingTree: BrowsingTree
    @Published var privateMode = false

    var state: BeamState!

    public private(set) var note: BeamNote
    public private(set) var rootElement: BeamElement
    public private(set) var element: BeamElement?

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
        self.note.browsingSessions.append(browsingTree)

        if let elem = element {
            // reparent the element that has alreay been created
            self.rootElement.addChild(elem)
        } else {
            _ = addCurrentPageToNote()
        }
    }
    var appendToIndexer: (URL, Readability) -> Void = { _, _ in }

    var creationDate: Date = Date()
    var lastViewDate: Date = Date()

    public var onNewTabCreated: (BrowserTab) -> Void = { _ in }

    private var scope = Set<AnyCancellable>()

    class var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.tabFocusesLinks = true
//        config.preferences.plugInsEnabled = true
        config.preferences._setFullScreenEnabled(true)
        config.preferences.isFraudulentWebsiteWarningEnabled = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        return config
    }

    init(state: BeamState, originalQuery: String?, note: BeamNote, rootElement: BeamElement? = nil, id: UUID = UUID(), webView: WKWebView? = nil, createBullet: Bool = true) {
        self.state = state
        self.id = id
        self.note = note
        self.rootElement = rootElement ?? note
        self.originalQuery = originalQuery

        if let w = webView {
            self.webView = w
            backForwardList = w.backForwardList
        } else {
            let web = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
            web.wantsLayer = true
            web.allowsMagnification = true

            state.setup(webView: web)
            backForwardList = web.backForwardList
            self.webView = web
        }
        browsingTree = BrowsingTree(originalQuery ?? webView?.url?.absoluteString)

        super.init(frame: .zero)
        note.browsingSessions.append(browsingTree)
        setupObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalQuery
        case url
        case browsingTree
        case privateMode
        case note
        case rootElement
        case element

    }

    var preloadUrl: URL?

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.originalQuery = try container.decode(String.self, forKey: .originalQuery)
        self.preloadUrl = try? container.decode(URL.self, forKey: .url)

        self.browsingTree = try container.decode(BrowsingTree.self, forKey: .browsingTree)
        self.privateMode = try container.decode(Bool.self, forKey: .privateMode)

        let noteName = try container.decode(String.self, forKey: .note)
        let loadedNote = BeamNote.fetch(AppDelegate.main.documentManager, title: noteName) ?? AppDelegate.main.data.todaysNote
        self.note = loadedNote
        let rootId = try? container.decode(UUID.self, forKey: .rootElement)
        self.rootElement = note.findElement(rootId ?? loadedNote.id) ?? loadedNote.children.first!
        if let elementId = try? container.decode(UUID.self, forKey: .element) {
            self.element = loadedNote.findElement(elementId)
        }

        super.init(frame: .zero)
        note.browsingSessions.append(browsingTree)
    }

    func postLoadSetup(state: BeamState) {
        self.state = state
        let web = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
        web.wantsLayer = true
        web.allowsMagnification = true

        state.setup(webView: web)
        backForwardList = web.backForwardList
        self.webView = web
//        setupObservers()
            if let _url = self.preloadUrl {
                self.preloadUrl = nil
                DispatchQueue.main.async { [weak self] in
                    self?.webView.load(URLRequest(url: _url))
                }
            }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(originalQuery, forKey: .originalQuery)
        if let _url = webView.url {
            try container.encode(_url, forKey: .url)
        }
        try container.encode(browsingTree, forKey: .browsingTree)
        try container.encode(privateMode, forKey: .privateMode)
        try container.encode(note.title, forKey: .note)
        try container.encode(rootElement.id, forKey: .rootElement)
        if let element = element {
            try container.encode(element, forKey: .element)
        }
    }

    // Add the current page to the current note and return the beam element (if the element already exist return it directly)
    func addCurrentPageToNote() -> BeamElement? {
        guard let elem = element else {
            guard let url = url else { return nil }
            guard !url.isSearchResult else { return nil } // Don't automatically add search results
            let linkString = url.absoluteString
            guard !note.outLinks.contains(linkString) else { element = note.elementContainingLink(to: linkString); return element }
            Logger.shared.logDebug("add current page '\(title)' to note '\(note.title)'", category: .web)
            let e = BeamElement()
            element = e
            updateElementWithTitle()
            rootElement.addChild(e)
            return e
        }
        return elem
    }

    private func updateElementWithTitle(_ title: String? = nil) {
        if let url = url, let element = element {
            let name = title ?? (self.title.isEmpty ? url.absoluteString : self.title)
            element.text = BeamText(text: name, attributes: [.link(url.absoluteString)])
        }
    }

    private func updateFavIcon() {
        guard let url = url else { favIcon = nil; return }
        FaviconProvider.shared.imageForUrl(url) { [weak self] (image) in
            guard let self = self else { return }
            self.favIcon = image
        }
    }

    private func updateScore() {
        let s = browsingTree.current.score.score
//            Logger.shared.logDebug("updated score[\(url!.absoluteString)] = \(s)", category: .general)
        element?.score = s
        if s > 0.0 {
            _ = addCurrentPageToNote() // Automatically add current page to note over a certain threshold
        }
    }

    var backListSize = 0
    private func setupObservers() {
        webView.publisher(for: \.title).sink { v in
            self.title = v ?? "loading..."
            self.updateElementWithTitle()
        }.store(in: &scope)
        webView.publisher(for: \.url).sink { v in
            self.url = v
            if v?.absoluteString != nil {
                self.updateFavIcon()
//                self.browsingTree.current.score.openIndex = self.navigationCount
//                self.updateScore()
//                self.navigationCount = 0
            }
        }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink { v in withAnimation { self.isLoading = v } }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink { v in withAnimation { self.estimatedProgress = v } }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent).sink { v in self.hasOnlySecureContent = v }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink { v in self.serverTrust = v }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink { v in self.canGoBack = v }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink { v in self.canGoForward = v }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink { v in self.backForwardList = v }.store(in: &scope)

        webView.navigationDelegate = self
        webView.uiDelegate = self

        removeScriptHandlers()
        removeUserScripts()

        addScriptHandlers()
        addUserScripts()
    }

    func cancelObservers() {
        scope.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        removeScriptHandlers()
    }

    private func removeUserScripts() {
        self.webView.configuration.userContentController.removeAllUserScripts()
    }

    private func addUserScripts() {
        self.webView.configuration.userContentController.addUserScript(WKUserScript(source: overrideConsole, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        self.webView.configuration.userContentController.addUserScript(WKUserScript(source: jsSelectionObserver, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }

    private enum ScriptHandlers: String, CaseIterable {
        case beam_textSelected
        case beam_onScrolled
        case beam_logging
    }

    private func removeScriptHandlers() {
        ScriptHandlers.allCases.forEach {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    private func addScriptHandlers() {
        ScriptHandlers.allCases.forEach {
            let handler = $0.rawValue
            webView.configuration.userContentController.add(self, name: handler)
            Logger.shared.logDebug("Added Script handler: \(handler)", category: .web)
        }
    }

    private var currentBackForwardItem: WKBackForwardListItem?
    private func handleBackForwardWebView(navigationAction: WKNavigationAction) {
        if navigationAction.navigationType == .backForward {
            let isBack = webView.backForwardList.backList
                .filter { $0 == currentBackForwardItem }
                .count == 0

            if isBack {
                browsingTree.goBack()
            } else {
                browsingTree.goForward()
            }
        }

        currentBackForwardItem = webView.backForwardList.currentItem
    }

    // WKNavigationDelegate:
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        element = nil
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        element = nil
        handleBackForwardWebView(navigationAction: navigationAction)
        if let targetURL = navigationAction.request.url {
            if navigationAction.modifierFlags.contains(.command) {
                // Create new tab
                let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
                newWebView.wantsLayer = true
                newWebView.allowsMagnification = true

                state.setup(webView: newWebView)
                let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: note, rootElement: rootElement, webView: newWebView)
                newTab.load(url: targetURL)
                newTab.browsingTree.current.score.openIndex = navigationCount
                navigationCount += 1
                onNewTabCreated(newTab)
                decisionHandler(.cancel, preferences)
                browsingTree.switchToOtherTab()

                return
            }

            visitedURLs.insert(targetURL)
        }

        decisionHandler(.allow, preferences)
    }

    var navigationCount: Int = 0

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        element = nil
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        element = nil
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        element = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        element = nil
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        element = nil
        _ = addCurrentPageToNote()
    }

    lazy var overrideConsole: String = { loadJS(from: "OverrideConsole") }()

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case ScriptHandlers.beam_logging.rawValue:
            Logger.shared.logInfo(String(describing: message.body), category: .javascript)

        case ScriptHandlers.beam_textSelected.rawValue:
            guard let dict = message.body as? [String: AnyObject],
//                  let selectedText = dict["selectedText"] as? String,
                  let selectedHtml = dict["selectedHtml"] as? String,
                  !selectedHtml.isEmpty
            else { return }

            let text: BeamText = html2Text(url: webView.url!, html: selectedHtml)
            browsingTree.current.score.textSelections += 1
            self.updateScore()

            // now add a bullet point with the quoted text:
            if let urlString = webView.url?.absoluteString, let title = webView.title {
                let quote = text

                DispatchQueue.main.async {
                    guard let current = self.addCurrentPageToNote() else { return }
                    let e = BeamElement()
                    e.kind = .quote(1, title, urlString)
                    e.text = quote
                    e.query = self.originalQuery
                    current.addChild(e)
                }
            }

        case ScriptHandlers.beam_onScrolled.rawValue:
            guard let dict = message.body as? [String: AnyObject],
//                  let selectedText = dict["selectedText"] as? String,
                let x = dict["x"] as? Double,
                let y = dict["y"] as? Double,
                let w = dict["width"] as? Double,
                let h = dict["height"] as? Double
            else { return }
            if w > 0, h > 0 {
                browsingTree.current.score.scrollRatioX = max(Float(x / w), browsingTree.current.score.scrollRatioX)
                browsingTree.current.score.scrollRatioY = max(Float(y / h), browsingTree.current.score.scrollRatioY)
                browsingTree.current.score.area = Float(w * h)
                self.updateScore()
            }
            Logger.shared.logDebug("Web Scrolled: \(x), \(y)", category: .web)
        default:
            break
        }
    }

    lazy var jsSelectionObserver: String = { loadJS(from: "SelectionObserver") }()

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        _ = addCurrentPageToNote()
        browsingTree.navigateTo(url: url.absoluteString, title: webView.title)
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(read):
                self.appendToIndexer(url, read)
                self.updateElementWithTitle(read.title)
                self.browsingTree.current.score.textAmount = read.content.count
                self.updateScore()
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        element = nil
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }

    // WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: configuration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: self.note, rootElement: rootElement, webView: newWebView)
        onNewTabCreated(newTab)

        return newTab.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        Logger.shared.logDebug("webView webDidClose", category: .web)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Logger.shared.logDebug("webView runJavaScriptAlertPanelWithMessage \(message)", category: .web)
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptConfirmPanelWithMessage \(message)", category: .web)
        completionHandler(true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptTextInputPanelWithPrompt \(prompt) default: \(defaultText ?? "")", category: .web)
        completionHandler(nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        Logger.shared.logDebug("webView runOpenPanel", category: .web)
        completionHandler(nil)
    }

    func startReading() {
        lastViewDate = Date()
        browsingTree.startReading()
    }

    func switchToCard() {
        browsingTree.switchToCard()
    }

    func switchToOtherTab() {
        browsingTree.switchToOtherTab()
    }

    func switchToNewSearch() {
        browsingTree.switchToNewSearch()
    }

    func goBack() {
        browsingTree.goBack()
        webView.goBack()
    }

    func goForward() {
        browsingTree.goForward()
        webView.goForward()
    }

    func switchToBackground() {
        browsingTree.switchToBackground()
    }
}
