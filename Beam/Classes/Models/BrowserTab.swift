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
import BeamCore

class FullScreenWKWebView: WKWebView {
//    override var safeAreaInsets: NSEdgeInsets {
//        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    }

    // Catching those event to avoid funk sound
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
class BrowserTab: NSView, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, Codable,
        WebPage, BrowsingScorer {
    var id: UUID

    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    private var pixelRatio: Double = 1

    public func load(url: URL) {
        self.url = url
        navigationCount = 0
        webView.load(URLRequest(url: url))
        $isLoading.sink { [weak passwordOverlayController] loading in
            if !loading {
                passwordOverlayController?.detectInputFields()
            }
        }.store(in: &scope)
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

    var pointAndShootAllowed: Bool {
        url?.isSearchResult != true
    }

    var currentScore: Score { self.browsingTree.current.score }

    lazy var passwordOverlayController: PasswordOverlayController = PasswordOverlayController(webView: webView)

    lazy var webPositions: WebPositions = messageHandler!.webPositions

    var state: BeamState!
    public private(set) var note: BeamNote
    public private(set) var rootElement: BeamElement

    public private(set) var element: BeamElement?

    var messageHandler: WebMessageHandler?

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
        self.note.browsingSessions.append(browsingTree)
        state.destinationCardName = note.title

        if let elem = element {
            // reparent the element that has alreay been created
            self.rootElement.addChild(elem)
        } else {
            _ = addToNote()
        }
    }

    var appendToIndexer: (URL, Readability) -> Void = { _, _ in
    }
    var creationDate: Date = Date()

    var lastViewDate: Date = Date()

    public var onNewTabCreated: (BrowserTab) -> Void = { _ in
    }

    private var scope = Set<AnyCancellable>()

    class var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.tabFocusesLinks = true
//        config.preferences.plugInsEnabled = true
        config.preferences._setFullScreenEnabled(true)
        config.preferences.isFraudulentWebsiteWarningEnabled = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        return config
    }

    init(state: BeamState, originalQuery: String?, note: BeamNote, rootElement: BeamElement? = nil, id: UUID = UUID(),
         webView: WKWebView? = nil, createBullet: Bool = true) {
        self.state = state
        self.id = id
        self.note = note
        self.rootElement = rootElement ?? note
        self.originalQuery = originalQuery

        if let suppliedWebView = webView {
            self.webView = suppliedWebView
            backForwardList = suppliedWebView.backForwardList
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

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        originalQuery = try container.decode(String.self, forKey: .originalQuery)
        preloadUrl = try? container.decode(URL.self, forKey: .url)

        browsingTree = try container.decode(BrowsingTree.self, forKey: .browsingTree)
        privateMode = try container.decode(Bool.self, forKey: .privateMode)

        let noteTitle = try container.decode(String.self, forKey: .note)
        let loadedNote = BeamNote.fetch(AppDelegate.main.documentManager, title: noteTitle)
                ?? AppDelegate.main.data.todaysNote
        note = loadedNote
        let rootId = try? container.decode(UUID.self, forKey: .rootElement)
        rootElement = note.findElement(rootId ?? loadedNote.id) ?? loadedNote.children.first!
        if let elementId = try? container.decode(UUID.self, forKey: .element) {
            element = loadedNote.findElement(elementId)
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
        webView = web
//        setupObservers()
        if let suppliedPreloadURL = preloadUrl {
            preloadUrl = nil
            DispatchQueue.main.async { [weak self] in
                self?.webView.load(URLRequest(url: suppliedPreloadURL))
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(originalQuery, forKey: .originalQuery)
        if let currentURL = webView.url {
            try container.encode(currentURL, forKey: .url)
        }
        try container.encode(browsingTree, forKey: .browsingTree)
        try container.encode(privateMode, forKey: .privateMode)
        try container.encode(note.title, forKey: .note)
        try container.encode(rootElement.id, forKey: .rootElement)
        if let element = element {
            try container.encode(element, forKey: .element)
        }
    }

    // Add the current page to the current note and return the beam element
    // (if the element already exist return it directly)

    func addToNote(allowSearchResult: Bool = false) -> BeamElement? {
        guard let elem = element else {
            guard let url = self.url else {
                Logger.shared.logError("Cannot get current URL", category: .general)
                return nil
            }
            guard allowSearchResult || !url.isSearchResult else {
                Logger.shared.logWarning("Adding search results is not allowed", category: .web)
                return nil
            } // Don't automatically add search results
            let linkString = url.absoluteString
            guard !note.outLinks.contains(linkString) else {
                element = note.elementContainingLink(to: linkString); return element
            }
            Logger.shared.logDebug("add current page '\(title)' to note '\(note.title)'", category: .web)
            if rootElement.children.count == 1,
               let firstElement = rootElement.children.first,
               firstElement.text.isEmpty {
                element = firstElement
            } else {
                let newElement = BeamElement()
                element = newElement
                rootElement.addChild(newElement)
            }
            updateElementWithTitle()
            return element
        }
        return elem
    }

    private func receivedWebviewTitle(_ title: String? = nil) {
        updateElementWithTitle(title)
        guard title?.isEmpty == false || !isLoading else {
            return
        }
        self.title = title ?? ""
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

    func updateScore() {
        let score = browsingTree.current.score.score
//            Logger.shared.logDebug("updated score[\(url!.absoluteString)] = \(s)", category: .general)
        element?.score = score
        if score > 0.0 {
            _ = addToNote() // Automatically add current page to note over a certain threshold
        }
    }

    func addTextSelection() {
        browsingTree.current.score.textSelections += 1
    }

    func getNote(fromTitle noteTitle: String) -> BeamNote? {
        BeamNote.fetch(state.data.documentManager, title: noteTitle)
    }

    var backListSize = 0

    private func setupObservers() {
        Logger.shared.logDebug("setupObservers")
        webView.publisher(for: \.title).sink { value in
            self.receivedWebviewTitle(value)
        }.store(in: &scope)
        webView.publisher(for: \.url).sink { value in
            self.url = value
            if value?.absoluteString != nil {
                self.updateFavIcon()
                // self.browsingTree.current.score.openIndex = self.navigationCount
                // self.updateScore()
                // self.navigationCount = 0
            }
        }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink { value in withAnimation { self.isLoading = value } }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink { value in
            withAnimation { self.estimatedProgress = value }
        }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent)
                .sink { value in self.hasOnlySecureContent = value }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink { value in self.serverTrust = value }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink { value in self.canGoBack = value }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink { value in self.canGoForward = value }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink { value in self.backForwardList = value }.store(in: &scope)

        webView.navigationDelegate = self
        webView.uiDelegate = self

        removeUserScripts()

        if messageHandler != nil {
            messageHandler!.destroy(for: webView)
        }
        let webPositions: WebPositions = WebPositions()
        // Avoid instantiate if !pointAndShootEnabled
        let pointAndShoot = PointAndShoot(page: self, ui: PointAndShootUI(), browsingScorer: self,
                                          webPositions: webPositions)
        messageHandler = WebMessageHandler(page: self, webPositions: webPositions, browsingScorer: self, pointAndShoot: pointAndShoot, passwordOverlayController: passwordOverlayController)
        messageHandler!.addScriptHandlers(to: webView)

        addUserScripts()
    }

    func cancelObservers() {
        scope.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        messageHandler?.destroy(for: webView)
    }

    private func removeUserScripts() {
        messageHandler?.removeScriptHandlers(from: webView)
    }

    lazy var devTools: String = {
        loadFile(from: "DevTools", fileType: "js")
    }()

    private func addUserScripts() {
        addJS(source: overrideConsole, when: .atDocumentStart)
        messageHandler!.pointAndShoot.injectScripts()
        addJS(source: jsPasswordManager, when: .atDocumentEnd)
        //    addJS(source: devTools, when: .atDocumentEnd)
    }

    private func obfuscate(parameterized: String) -> String {
        parameterized.replacingOccurrences(of: "__ID__",
                                           with: "beam" + id.uuidString.replacingOccurrences(of: "-", with: "_"))
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        let parameterized = source.replacingOccurrences(of: "__ENABLED__", with: "true")
        let obfuscated = obfuscate(parameterized: parameterized)
        let script = WKUserScript(source: obfuscated, injectionTime: when, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }

    func executeJS(objectName: String, jsCode: String) {
        let parameterized = "__ID__\(objectName)." + jsCode
        let obfuscatedCommand = obfuscate(parameterized: parameterized)
        webView.evaluateJavaScript(obfuscatedCommand) { (result, error) in
            if error == nil {
                Logger.shared.logInfo("(\(obfuscatedCommand) succeeded: \(String(describing: result))",
                                      category: .javascript)
            } else {
                Logger.shared.logError("(\(obfuscatedCommand) failed: \(String(describing: error))",
                                       category: .javascript)
            }
        }
    }

    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        let styleSrc = """
                       var style = document.createElement('style');
                       style.innerHTML = `\(source)`;
                       document.head.appendChild(style);
                       """
        addJS(source: styleSrc, when: when)
    }

    private var currentBackForwardItem: WKBackForwardListItem?

    private func handleBackForwardWebView(navigationAction: WKNavigationAction) {
        if navigationAction.navigationType == .backForward {
            let isBack = webView.backForwardList.backList
                    .filter {
                $0 == currentBackForwardItem
            }
                    .count == 0

            if isBack {
                browsingTree.goBack()
            } else {
                browsingTree.goForward()
            }
        }
        messageHandler!.pointAndShoot.removeAll()
        currentBackForwardItem = webView.backForwardList.currentItem
    }

    // WKNavigationDelegate:
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        element = nil
        messageHandler!.pointAndShoot.removeAll()
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        element = nil
        handleBackForwardWebView(navigationAction: navigationAction)
        if let targetURL = navigationAction.request.url {
            if navigationAction.modifierFlags.contains(.command) {
                // Create new tab
                let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
                newWebView.wantsLayer = true
                newWebView.allowsMagnification = true

                state.setup(webView: newWebView)
                let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: note,
                                        rootElement: rootElement, webView: newWebView)
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

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
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
        Logger.shared.logError("didfail: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        element = nil
        _ = addToNote()
    }

    lazy var overrideConsole: String = {
        loadFile(from: "OverrideConsole", fileType: "js")
    }()
    lazy var jsPasswordManager: String = {
        loadFile(from: "PasswordManager", fileType: "js")
    }()

    func cancelShoot() {
        messageHandler!.pointAndShoot.resetStatus()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        _ = addToNote()
        browsingTree.navigateTo(url: url.absoluteString, title: webView.title)
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):
                self.appendToIndexer(url, read)
                self.updateElementWithTitle(webView.title)
                self.browsingTree.current.score.textAmount = read.content.count
                self.updateScore()
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        element = nil
        Logger.shared.logError("Webview failed: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }

    // WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: configuration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: note, rootElement: rootElement,
                                webView: newWebView)
        onNewTabCreated(newTab)

        return newTab.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        Logger.shared.logDebug("webView webDidClose", category: .web)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Logger.shared.logDebug("webView runJavaScriptAlertPanelWithMessage \(message)", category: .web)
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptConfirmPanelWithMessage \(message)", category: .web)
        completionHandler(true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptTextInputPanelWithPrompt \(prompt) default: \(defaultText ?? "")",
                               category: .web)
        completionHandler(nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
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
