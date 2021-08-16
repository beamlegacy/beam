import Foundation
import SwiftUI
import Combine
import WebKit
import BeamCore
import Promises

// swiftlint:disable:next type_body_length
@objc class BrowserTab: NSObject, ObservableObject, Identifiable, Codable, WebPage, Scorable {

    var id: UUID

    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    var width: CGFloat = 0
    var height: CGFloat = 0
    private var pixelRatio: Double = 1

    let uiDelegateController = BeamWebkitUIDelegateController()
    let noteController: WebNoteController

    private var isFromNoteSearch: Bool

    public func load(url: URL) {
        if !isFromNoteSearch {
            navigationController?.setLoading()
        }
        beamNavigationController.isNavigatingFromNote = isFromNoteSearch
        self.url = url
        navigationCount = 0
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            // Google Sheets shows an error message when using the Safari User Agent
            // The alternative of setting the applicationNameForUserAgent in BeamWebViewConfiguration
            // creates unexpected behaviour on google search results pages.
            // Source: https://github.com/sindresorhus/Plash/blob/main/Plash/WebViewController.swift#L69-L72
            if url.host == "docs.google.com" {
                webView.customUserAgent = ""
            } else {
                webView.customUserAgent = Constants.SafariUserAgent
            }

            webView.load(URLRequest(url: url))
        }
        $isLoading.sink { [unowned passwordOverlayController] loading in
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
    @Published var favIcon: NSImage?

    @Published var browsingTree: BrowsingTree
    @Published var privateMode = false

    @Published var authenticationViewModel: AuthenticationViewModel?

    var backForwardUrlList: [URL]?

    var originMode: Mode

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
        pointAndShoot?.leavePage()
    }

    func navigatedTo(url: URL, title: String?, reason: NoteElementAddReason) {
        logInNote(url: url, title: title, reason: reason)
        updateScore()
    }

    @discardableResult
    private func logInNote(url: URL, title: String?, reason: NoteElementAddReason) -> BeamElement? {
        var elementToFocus: BeamElement?
        if isFromNoteSearch {
            noteController.setContents(url: url, text: title)
            isFromNoteSearch = false
            elementToFocus = noteController.element
        } else {
            elementToFocus = noteController.add(url: url, text: title, reason: reason, isNavigatingFromNote: beamNavigationController.isNavigatingFromNote, browsingOrigin: self.browsingTree.origin)
        }
        if let elementToFocus = elementToFocus {
            updateFocusedStateToElement(elementToFocus)
            return elementToFocus
        } else {
            return nil
        }
    }

    private func updateFocusedStateToElement(_ element: BeamElement) {
        state.updateNoteFocusedState(note: noteController.note,
                                     focusedElement: element.id,
                                     cursorPosition: element.text.wholeRange.upperBound)
    }

    lazy var passwordOverlayController: PasswordOverlayController? = {
        let controller = PasswordOverlayController(passwordStore: state.data.passwordsDB, userInfoStore: MockUserInformationsStore.shared)
        controller.page = self
        return controller
    }()

    lazy var browsingScorer: BrowsingScorer? = {
        let scorer = BrowsingTreeScorer(browsingTree: browsingTree)
        scorer.page = self
        return scorer
    }()

    lazy var pointAndShoot: PointAndShoot? = {
        guard let scorer = browsingScorer else { return nil }
        let pns = PointAndShoot(scorer: scorer)
        pns.page = self
        return pns
    }()

    var navigationController: WebNavigationController? {
        beamNavigationController
    }

    lazy var beamNavigationController: BeamWebNavigationController = {
        let navController = BeamWebNavigationController(browsingTree: browsingTree, noteController: noteController, webView: webView)
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

    var downloadManager: DownloadManager? {
        state.data.downloadManager
    }

    var frame: NSRect {
        webView.frame
    }

    var fileStorage: BeamFileStorage? {
        state.data.fileDB
    }

    var passwordDB: PasswordsDB? {
        state.data.passwordsDB
    }

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        noteController.setDestination(note: note)
        state.destinationCardName = note.title
        browsingTree.destinationNoteChange()
    }

    var appendToIndexer: ((URL, Readability) -> Void)?
    var creationDate: Date = BeamDate.now

    var lastViewDate: Date = BeamDate.now

    public var onNewTabCreated: ((BrowserTab) -> Void)?

    private var scope = Set<AnyCancellable>()

    static var webViewConfiguration = BrowserTabConfiguration()
    var browsingTreeOrigin: BrowsingTreeOrigin?

    /**

     - Parameters:
       - state:
       - browsingTreeOrigin:
       - note: The destination note to add elements to.
       - rootElement: The root element to add elements to.
           Will be nil if you created a new tab from omniBar for instance.
           Will be the origin text element if you created the tab using Cmd+Enter.
       - id:
       - webView:
     */
    init(state: BeamState, browsingTreeOrigin: BrowsingTreeOrigin?, originMode: Mode, note: BeamNote?, rootElement: BeamElement? = nil,
         id: UUID = UUID(), webView: BeamWebView? = nil) {
        self.state = state
        self.id = id
        self.browsingTreeOrigin = browsingTreeOrigin
        self.originMode = originMode
        isFromNoteSearch = rootElement != nil

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

        browsingTree = BrowsingTree(
            browsingTreeOrigin,
            frecencyScorer: ExponentialFrecencyScorer(storage: GRDBFrecencyStorage()),
            longTermScoreStore: LongTermUrlScoreStore()
        )
        noteController = WebNoteController(note: note, rootElement: rootElement)

        super.init()

        self.webView.page = self
        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
        noteController.note.browsingSessions.append(browsingTree)
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
        case backForwardUrlList
        case browsingTree
        case privateMode
        case noteController
    }

    var preloadUrl: URL?

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        originalQuery = try? container.decode(String.self, forKey: .originalQuery)
        preloadUrl = try? container.decode(URL.self, forKey: .url)
        backForwardUrlList = try container.decode([URL].self, forKey: .backForwardUrlList)

        let tree: BrowsingTree = try container.decode(BrowsingTree.self, forKey: .browsingTree)
        browsingTree = tree
        noteController = try container.decode(WebNoteController.self, forKey: .noteController)
        privateMode = try container.decode(Bool.self, forKey: .privateMode)
        isFromNoteSearch = false

        originMode = .today
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
        self.webView.page = self
        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
        setupObservers()
        if let backForwardListUrl = backForwardUrlList {
            for url in backForwardListUrl {
                self.webView.load(URLRequest(url: url))
            }
            self.backForwardUrlList = nil
        }
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
        if let originalQuery = originalQuery {
            try container.encode(originalQuery, forKey: .originalQuery)
        }
        if let currentURL = webView.url {
            try container.encode(currentURL, forKey: .url)
        }
        var backForwardUrlList = [URL]()
        for backForwardListItem in webView.backForwardList.backList {
            backForwardUrlList.append(backForwardListItem.url)
        }
        try container.encode(backForwardUrlList, forKey: .backForwardUrlList)

        try container.encode(browsingTree, forKey: .browsingTree)
        try container.encode(privateMode, forKey: .privateMode)
        try container.encode(noteController, forKey: .noteController)
    }

    func addToNote(allowSearchResult: Bool) -> BeamElement? {
        guard let url = url else {
            Logger.shared.logError("Cannot get current URL", category: .general)
            return nil
        }
        guard allowSearchResult || SearchEngines.get(url) != nil else {
            Logger.shared.logWarning("Adding search results is not allowed", category: .web)
            return nil
        } // Don't automatically add search results

        let element = noteController.addContent(url: url, text: title, reason: .pointandshoot)
        return element
    }

    private func receivedWebviewTitle(_ title: String? = nil) {
        guard let url = url else {
            return
        }
        logInNote(url: url, title: title, reason: .loading)
        self.title = title ?? ""
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

    /// When using Point and Shoot to capture text in a webpage, notify the
    /// clustering manager, so the important text can be taken into consideration
    /// in the clustering process
    ///
    /// - Parameters:
    ///   - text: The text that was captured, as a string. If possible - the cleaner the
    ///   better (the text shouldn't include the caption of a photo, for example). If no text was captured,
    ///   this function should not be called.
    ///   - url: The url of the page the PnS was performed in.
    ///
    func addTextToClusteringManager(_ text: String, url: URL) {
        let clusteringManager = state.data.clusteringManager
        let id = browsingTree.current.link
        clusteringManager.addPage(id: id, parentId: nil, newContent: text)
    }

    private func setupObservers() {
        Logger.shared.logDebug("setupObservers", category: .javascript)
        webView.publisher(for: \.title).sink { [unowned self] value in
            self.receivedWebviewTitle(value)
        }.store(in: &scope)
        webView.publisher(for: \.url).sink { [unowned self] value in
            url = value
            leave()
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

    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
    }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, state: BeamState) -> WebPage {
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

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage {
        createNewTab(targetURL, configuration, setCurrent: setCurrent, state: state)
    }

    func createNewWindow(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        // TODO: Open a new window compliant with windowFeatures instead.
        let defaultValue = true
        let menubar = windowFeatures.menuBarVisibility?.boolValue ?? defaultValue
        let statusBar = windowFeatures.statusBarVisibility?.boolValue ?? defaultValue
        let toolBars = windowFeatures.toolbarsVisibility?.boolValue ?? defaultValue
        let resizing = windowFeatures.allowsResizing?.boolValue ?? defaultValue

        let x = windowFeatures.x?.floatValue ?? 0
        let y = windowFeatures.y?.floatValue ?? 0
        let width = windowFeatures.width?.floatValue ?? Float(webviewWindow?.frame.width ?? 800)
        let height = windowFeatures.height?.floatValue ?? Float(webviewWindow?.frame.height ?? 600)
        let windowFrame = NSRect(x: x, y: y, width: width, height: height)

        var newWebView: BeamWebView
        var newWindow: NSWindow
        if menubar && statusBar && toolBars && resizing {
            // we are being asked for the full browser experience, give it to them...
            let newBeamWindow = AppDelegate.main.createWindow(frame: windowFrame, reloadState: false)
            let tab = createNewTab(targetURL, configuration, setCurrent: setCurrent, state: newBeamWindow.state)
            newWindow = newBeamWindow
            newWebView = tab.webView
        } else {
            // this is more likely a login window or something that should disappear at some point so let's create something transient:
            newWebView = BeamWebView(frame: NSRect(), configuration: configuration ?? Self.webViewConfiguration)
            newWebView.enableAutoCloseWindow = true
            newWebView.wantsLayer = true
            newWebView.allowsMagnification = true
            state.setup(webView: newWebView)

            var windowMasks: NSWindow.StyleMask = [.closable, .miniaturizable, .titled, .unifiedTitleAndToolbar]
            if windowFeatures.allowsResizing != 0 {
                windowMasks.insert(NSWindow.StyleMask.resizable)
            }
            newWindow = NSWindow(contentRect: windowFrame, styleMask: windowMasks, backing: .buffered, defer: true)
            newWindow.isReleasedWhenClosed = false
            newWindow.contentView = newWebView

            newWindow.makeKeyAndOrderFront(nil)
        }
        if windowFeatures.x == nil || windowFeatures.y == nil {
            newWindow.center()
        }
        return newWebView
    }

    var navigationCount: Int = 0

    func startReading() {
        lastViewDate = BeamDate.now
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

    func respondToEscapeKey() {
        passwordOverlayController?.dismiss()
    }

    func passwordManagerToast(saved: Bool) {
        state.overlayViewModel.toastView = AnyView(CredentialsConfirmationToast(saved: saved))
    }

    func closeTab() {
        authenticationViewModel?.cancel()
        browsingTree.closeTab()
        sendTree()
    }

    func closeApp() {
        authenticationViewModel?.cancel()
        browsingTree.closeApp()
        sendTree(blocking: true)
    }

    private func sendTree(blocking: Bool = false) {
        guard let sender = state.data.browsingTreeSender else { return }
        if blocking {
            sender.blockingSend(browsingTree: browsingTree)
        } else {
            sender.send(browsingTree: browsingTree)
        }
    }
    // swiftlint:disable:next file_length
}
