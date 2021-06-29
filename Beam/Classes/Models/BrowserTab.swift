import Foundation
import SwiftUI
import Combine
import WebKit
import BeamCore
import Promises

@objc class BrowserTab: NSObject, ObservableObject, Identifiable, Codable, WebPage, Scorable {
    var id: UUID

    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    var width: CGFloat = 0
    var height: CGFloat = 0
    private var pixelRatio: Double = 1

    let uiDelegateController = BeamWebkitUIDelegateController()
    let noteController: WebNoteController

    public func load(url: URL) {
        navigationController.setLoading()
        self.url = url
        navigationCount = 0
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
        $isLoading.sink { [unowned passwordOverlayController] loading in
            if !loading {
                passwordOverlayController.detectInputFields()
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
    @Published var favIcon: NSImage?

    @Published var browsingTree: BrowsingTree
    @Published var privateMode = false

    var pointAndShootAllowed: Bool {
        true
    }

    var allowsPictureInPicture: Bool {
        Self.webViewConfiguration.allowsPictureInPicture
    }

    func isActiveTab() -> Bool {
        self == state.browserTabsManager.currentTab
    }

    func leave() {
        pointAndShoot.leavePage()
    }

    func navigatedTo(url: URL, read: Readability, title: String, isNavigation: Bool) {
        appendToIndexer?(url, read)
        noteController.add(url: url, text: title, isNavigation: isNavigation)
        updateScore()
    }

    lazy var passwordOverlayController: PasswordOverlayController = {
        let controller = PasswordOverlayController(passwordStore: state.data.passwordsDB, userInfoStore: MockUserInformationsStore.shared)
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

    var navigationController: WebNavigationController {
        return beamNavigationController
    }

    lazy var beamNavigationController: BeamWebNavigationController = {
        let navController = BeamWebNavigationController(browsingTree: browsingTree, noteController: noteController)
        navController.page = self
        return navController
    }()

    @Published var mediaPlayerController: MediaPlayerController?

    var state: BeamState!

    public var score: Float {
        get { noteController.score }
        set { noteController.score = newValue }
    }

    var webviewWindow: NSWindow? {
        webView.window
    }

    var downloadManager: DownloadManager {
        state.downloadManager
    }

    var frame: NSRect {
        webView.frame
    }

    var fileStorage: BeamFileStorage {
        state.data.fileDB
    }

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        noteController.setDestination(note: note)
        state.destinationCardName = note.title
        browsingTree.destinationNoteChange()
    }

    var appendToIndexer: ((URL, Readability) -> Void)?
    var creationDate: Date = Date()

    var lastViewDate: Date = Date()

    public var onNewTabCreated: ((BrowserTab) -> Void)?

    private var scope = Set<AnyCancellable>()

    static var webViewConfiguration = BrowserTabConfiguration()
    var browsingTreeOrigin: BrowsingTreeOrigin?

    init(state: BeamState, browsingTreeOrigin: BrowsingTreeOrigin?, note: BeamNote, rootElement: BeamElement? = nil,
         id: UUID = UUID(), webView: BeamWebView? = nil) {
        self.state = state
        self.id = id
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

        browsingTree = BrowsingTree(browsingTreeOrigin, frecencyScorer: ExponentialFrecencyScorer(storage: GRDBFrecencyStorage()))
        noteController = WebNoteController(note: note, rootElement: rootElement)

        super.init()

        self.webView.page = self
        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
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
        case noteController
    }

    var preloadUrl: URL?

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        originalQuery = try container.decode(String.self, forKey: .originalQuery)
        preloadUrl = try? container.decode(URL.self, forKey: .url)

        let tree: BrowsingTree = try container.decode(BrowsingTree.self, forKey: .browsingTree)
        browsingTree = tree
        noteController = try container.decode(WebNoteController.self, forKey: .noteController)
        privateMode = try container.decode(Bool.self, forKey: .privateMode)

        super.init()
        noteController.note.browsingSessions.append(tree)
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
        try container.encode(noteController, forKey: .noteController)
    }

    func addToNote(allowSearchResult: Bool) -> BeamElement? {
        guard let url = url else {
            Logger.shared.logError("Cannot get current URL", category: .general)
            return nil
        }
        guard allowSearchResult || !url.isSearchResult else {
            Logger.shared.logWarning("Adding search results is not allowed", category: .web)
            return nil
        } // Don't automatically add search results
        return noteController.add(url: url, text: title)
    }

    private func receivedWebviewTitle(_ title: String? = nil) {
        guard let url = url else {
            return
        }
        noteController.add(url: url, text: title)
        self.title = noteController.element.text.text
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
        noteController.score = score
    }

    func getNote(fromTitle noteTitle: String) -> BeamNote? {
        BeamNote.fetch(state.data.documentManager, title: noteTitle)
    }

    var backListSize = 0

    private func setupObservers() {
        Logger.shared.logDebug("setupObservers", category: .javascript)
        webView.publisher(for: \.title).sink { [unowned self] value in
            self.receivedWebviewTitle(value)
        }.store(in: &scope)
        webView.publisher(for: \.url).sink { [unowned self] value in
            url = value
            if value?.absoluteString != nil {
                updateFavIcon()
                // self.browsingTree.current.score.openIndex = self.navigationCount
                // self.updateScore()
                // self.navigationCount = 0
            }
        }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink { [unowned self] value in withAnimation { isLoading = value } }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink { [unowned self] value in
            withAnimation { estimatedProgress = value }
        }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent)
            .sink { [unowned self] value in hasOnlySecureContent = value }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink { [unowned self] value in serverTrust = value }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink { [unowned self] value in canGoBack = value }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink { [unowned self] value in canGoForward = value }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink { [unowned self] value in backForwardList = value }.store(in: &scope)

        webView.navigationDelegate = beamNavigationController
        webView.uiDelegate = uiDelegateController
    }

    func cancelObservers() {
        scope.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?> {
        Promise<Any?> { [unowned self] fulfill, reject in
            let parameterized = objectName != nil ? "beam.__ID__\(objectName!)." + jsCode : jsCode
            let obfuscatedCommand = Self.webViewConfiguration.obfuscate(str: parameterized)

            webView.evaluateJavaScript(obfuscatedCommand) { (result, error: Error?) in
                if error == nil {
                    Logger.shared.logInfo("(\(obfuscatedCommand) succeeded: \(String(describing: result))", category: .javascript)
                    fulfill(result)
                } else {
                    Logger.shared.logError("(\(obfuscatedCommand) failed: \(String(describing: error))", category: .javascript)
                    reject(error!)
                }
            }

        }
    }

    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
    }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage {
        let newWebView = BeamWebView(frame: NSRect(), configuration: configuration ?? Self.webViewConfiguration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let origin = BrowsingTreeOrigin.browsingNode(id: browsingTree.current.id)
        let newTab = state.addNewTab(origin: origin, setCurrent: setCurrent,
                                     note: noteController.note, element: noteController.rootElement,
                                     url: targetURL, webView: newWebView)
        newTab.browsingTree.current.score.openIndex = navigationCount
        navigationCount += 1
        browsingTree.openLinkInNewTab()
        return newTab
    }

    var navigationCount: Int = 0

    func cancelShoot() {
        pointAndShoot.resetStatus()
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

    func passwordManagerToast(saved: Bool) {
        state.overlayViewModel.credentialsToast = CredentialsConfirmationToast(saved: saved)
    }

    func closeTab() {
        browsingTree.closeTab()
    }

    func closeApp() {
        browsingTree.closeApp()
    }
}
