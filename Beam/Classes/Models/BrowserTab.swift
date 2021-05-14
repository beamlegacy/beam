import Foundation
import SwiftUI
import Combine
import WebKit
import BeamCore
import Promises

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class BrowserTab: NSView, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, Codable, WebPage, Scorable {

    var id: UUID

    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    var width: CGFloat = 0
    var height: CGFloat = 0
    private var pixelRatio: Double = 1

    public func load(url: URL) {
        isNavigatingFromSearchBar = true
        self.url = url
        navigationCount = 0
        webView.load(URLRequest(url: url))
        $isLoading.sink { [weak passwordOverlayController] loading in
            if !loading {
                passwordOverlayController?.detectInputFields()
            }
        }.store(in: &scope)
    }

    @Published public var webView: BeamWebView! {
        didSet {
            setupObservers()
        }
    }

    @Published var title: String = "New Tab"
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

    private var isCurrent: Bool {
        self == state.browserTabsManager.currentTab
    }

    lazy var passwordOverlayController: PasswordOverlayController = {
        let controller = PasswordOverlayController(passwordStore: MockPasswordStore.shared)
        controller.page = self
        return controller
    }()

    lazy var browsingScorer: BrowsingScorer = {
        let scorer = BrowsingTreeScorer(browsingTree: browsingTree)
        scorer.page = self
        return scorer
    }()

    lazy var pointAndShoot: PointAndShoot = {
        let pns = PointAndShoot(ui: PointAndShootUI(), scorer: browsingScorer)
        pns.page = self
        return pns
    }()

    private var isNavigatingFromSearchBar: Bool = false

    var state: BeamState!
    public private(set) var note: BeamNote
    public private(set) var rootElement: BeamElement

    public private(set) var element: BeamElement?

    public var score: Float {
        get { element?.score ?? 0 }
        set { element?.score = newValue }
    }

    var webviewWindow: NSWindow? {
        self.webView.window
    }

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
        self.note.browsingSessions.append(browsingTree)
        state.destinationCardName = note.title

        if let elem = element {
            // re-parent the element that has already been created
            self.rootElement.addChild(elem)
        } else {
            _ = addToNote()
        }
    }

    var appendToIndexer: ((URL, Readability) -> Void)?
    var creationDate: Date = Date()

    var lastViewDate: Date = Date()

    public var onNewTabCreated: ((BrowserTab) -> Void)?

    private var scope = Set<AnyCancellable>()

    static var webViewConfiguration = BrowserTabConfiguration()
    var browsingTreeOrigin: BrowsingTreeOrigin?

    init(state: BeamState, browsingTreeOrigin: BrowsingTreeOrigin?, note: BeamNote, rootElement: BeamElement? = nil, id: UUID = UUID(),
         webView: BeamWebView? = nil) {
        self.state = state
        self.id = id
        self.note = note
        self.rootElement = rootElement ?? note
        self.browsingTreeOrigin = browsingTreeOrigin

        if let suppliedWebView = webView {
            self.webView = suppliedWebView
            backForwardList = suppliedWebView.backForwardList
        } else {
            let web = BeamWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
            web.wantsLayer = true
            web.allowsMagnification = true

            state.setup(webView: web)
            backForwardList = web.backForwardList
            self.webView = web
        }

        browsingTree = BrowsingTree(browsingTreeOrigin)

        super.init(frame: .zero)

        self.webView.page = self

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
        let web = BeamWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
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
            guard let url = url else {
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
        guard title?.isEmpty == false || (!isLoading && url != nil) else {
            return
        }
        self.title = title ?? ""
    }

    private func updateElementWithTitle(_ title: String? = nil) {
        guard let url = url, let element = element else {
            return
        }
        // only change element text if it contains only this link
        guard element.text.ranges.count == 1,
              let range = element.text.ranges.first,
              range.attributes.count <= 1 else {
            return
        }
        let name = title ?? (self.title.isEmpty ? url.absoluteString : self.title)
        element.text = BeamText(text: name, attributes: [.link(url.absoluteString)])
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
    }

    func cancelObservers() {
        scope.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?> {
        Promise<Any?> { [unowned self] fulfill, reject in
            let parameterized = objectName != nil ? "exports.__ID__\(objectName!)." + jsCode : jsCode
            let obfuscatedCommand = Self.webViewConfiguration.obfuscate(str: parameterized)
            webView.evaluateJavaScript(obfuscatedCommand) { (result, error: Error?) in
                if error == nil {
                    Logger.shared.logInfo("(\(obfuscatedCommand) succeeded: \(String(describing: result))",
                                          category: .javascript)
                    fulfill(result)
                } else {
                    Logger.shared.logError("(\(obfuscatedCommand) failed: \(String(describing: error))",
                                           category: .javascript)
                    reject(error!)
                }
            }
        }
    }

    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
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
        pointAndShoot.removeAll()
        currentBackForwardItem = webView.backForwardList.currentItem
    }

    // WKNavigationDelegate:
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        element = nil
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        element = nil
        handleBackForwardWebView(navigationAction: navigationAction)
        if let targetURL = navigationAction.request.url {
            if navigationAction.modifierFlags.contains(.command) {
                _ = createNewTab(targetURL, nil, setCurrent: false)
                decisionHandler(.cancel, preferences)
                return
            }
            visitedURLs.insert(targetURL)
        }
        decisionHandler(.allow, preferences)
    }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> BrowserTab {
        let newWebView = BeamWebView(frame: NSRect(), configuration: configuration ?? Self.webViewConfiguration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let origin = BrowsingTreeOrigin.browsingNode(id: browsingTree.current.id)
        let newTab = state.addNewTab(origin: origin, setCurrent: setCurrent, note: note, element: rootElement, url: targetURL, webView: newWebView)
        newTab.browsingTree.current.score.openIndex = navigationCount
        navigationCount += 1
        browsingTree.openLinkInNewTab()
        return newTab
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
        Logger.shared.logError("didFail: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        element = nil
        _ = addToNote()
    }

    func cancelShoot() {
        pointAndShoot.resetStatus()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        _ = addToNote()
        let isLinkActivation = !isNavigatingFromSearchBar
        browsingTree.navigateTo(url: url.absoluteString, title: webView.title, startReading: isCurrent, isLinkActivation: isLinkActivation)
        isNavigatingFromSearchBar = false
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):
                self.appendToIndexer?(url, read)
                self.updateElementWithTitle(webView.title)
                self.browsingTree.current.score.textAmount = read.content.count
                self.updateScore()
                try? TextSaver.shared?.save(nodeId: self.browsingTree.current.id, text: read)
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
        guard let url = navigationAction.request.url else { return nil }
        let newTab = createNewTab(url, configuration, setCurrent: true)
        return newTab.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        Logger.shared.logDebug("webView webDidClose", category: .web)
        browsingTree.closeTab()
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
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func switchToBackground() {
        browsingTree.switchToBackground()
    }

    func dumpBrowsingTree() {
        browsingTree.dump()
    }
}
