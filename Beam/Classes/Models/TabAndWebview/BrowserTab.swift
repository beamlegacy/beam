import Foundation
import SwiftUI
import Combine
import WebKit
import BeamCore
import Promises

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
@objc class BrowserTab: NSObject, ObservableObject, Identifiable, Codable, Scorable {

    var id: UUID = UUID()
    @Published var isLoading: Bool = false
    @Published var estimatedLoadingProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false

    @Published var serverTrust: SecTrust?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList!
    @Published var favIcon: NSImage?

    @Published var browsingTree: BrowsingTree
    @Published var privateMode = false
    @Published var isPinned = false
    @Published var screenshotCapture: NSImage?

    weak var state: BeamState? {
        didSet {
            guard oldValue != nil && state != oldValue else { return }
            tabDidChangeWindow()
        }
    }
    var preloadUrl: URL?
    var backForwardUrlList: [URL]?
    var originMode: Mode
    let uiDelegateController = BeamWebkitUIDelegateController()
    let noteController: WebNoteController
    internal var isFromNoteSearch: Bool = false
    var allowsPictureInPicture: Bool {
        Self.webViewConfiguration.allowsPictureInPicture
    }

    public var score: Float {
        get { noteController.score }
        set { noteController.score = newValue }
    }

    var creationDate: Date = BeamDate.now
    var lastViewDate: Date = BeamDate.now
    private var scope = Set<AnyCancellable>()

    static var webViewConfiguration = BrowserTabConfiguration()
    var browsingTreeOrigin: BrowsingTreeOrigin?

    var showsStatusBar: Bool {
        guard PreferencesManager.showsStatusBar else { return false }
        switch mouseHoveringLocation {
        case .none: return false
        case .link: return true
        }
    }

    // MARK: - WebPage properties
    @Published public var webView: BeamWebView! {
        didSet {
            setupObservers()
        }
    }
    var webviewWindow: NSWindow? { webView.window }
    var frame: NSRect { webView.frame }
    @Published var title: String = ""
    @Published var originalQuery: String?
    @Published var url: URL?
    @Published var requestedURL: URL?
    @Published var authenticationViewModel: AuthenticationViewModel?
    @Published var searchViewModel: SearchViewModel?
    @Published var mouseHoveringLocation: MouseHoveringLocation = .none
    @Published var responseStatusCode: Int = 200
    @Published var mediaPlayerController: MediaPlayerController?
    @Published var hasError: Bool = false {
        didSet {
            if !hasError {
                errorPageManager = nil
            }
        }
    }
    @Published var errorPageManager: ErrorPageManager? {
        didSet {
            if errorPageManager != nil {
                hasError = true
            }
        }
    }
    var fileStorage: BeamFileStorage? { BeamFileDBManager.shared }
    var downloadManager: DownloadManager? {
        state?.data.downloadManager
    }
    private var _navigationController: BeamWebNavigationController?
    var navigationController: WebNavigationController? {
        beamNavigationController
    }

    internal var beamNavigationController: BeamWebNavigationController? {
        guard _navigationController == nil else { return _navigationController }
        guard let webView = webView else { return nil }
        let navController = BeamWebNavigationController(browsingTree: browsingTree, noteController: noteController, webView: webView)
        navController.page = self
        _navigationController = navController
        return navController
    }

    lazy var passwordOverlayController: PasswordOverlayController? = {
        let controller = PasswordOverlayController(userInfoStore: MockUserInformationsStore.shared)
        controller.page = self
        return controller
    }()

    lazy var browsingScorer: BrowsingScorer? = {
        let scorer = BrowsingTreeScorer(browsingTree: browsingTree)
        scorer.page = self
        return scorer
    }()

    lazy var pointAndShoot: PointAndShoot? = {
        let pns = PointAndShoot()
        pns.page = self
        return pns
    }()
    var pointAndShootInstalled: Bool = true
    var pointAndShootEnabled: Bool {
        state?.focusOmniBox != true
    }
    lazy var webPositions: WebPositions? = {
        let webPositions = WebPositions()
        webPositions.delegate = self
        return webPositions
    }()
    var appendToIndexer: ((URL, _ title: String, Readability) -> Void)?
    var navigationCount: Int = 0
    // End WebPage Properties

    // MARK: - Init
    /**
     - Parameters:
       - state:
       - browsingTreeOrigin:
       - note: The destination note to add elements to.
       - rootElement: The root element to add elements to.
           Will be nil if you created a new tab from omnibox for instance.
           Will be the origin text element if you created the tab using Cmd+Enter.
       - id:
       - webView:
     */
    init(state: BeamState?, browsingTreeOrigin: BrowsingTreeOrigin?, originMode: Mode, note: BeamNote?, rootElement: BeamElement? = nil,
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
            let web = BeamWebView(frame: .zero, configuration: Self.webViewConfiguration)
            web.wantsLayer = true
            web.allowsMagnification = true

            state?.setup(webView: web)
            backForwardList = web.backForwardList
            self.webView = web
        }

        browsingTree = Self.newBrowsingTree(origin: browsingTreeOrigin)
        noteController = WebNoteController(note: note, rootElement: rootElement)

        super.init()
        self.webView.page = self
        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
        addTreeToNote()
        setupObservers()
        beamNavigationController?.isNavigatingFromNote = isFromNoteSearch
    }

    init(pinnedTabWithId id: UUID, url: URL, title: String) {
        self.id = id
        self.url = url
        self.preloadUrl = url
        self.title = title
        self.isPinned = true
        self.originMode = .web

        browsingTree = Self.newBrowsingTree(origin: browsingTreeOrigin)
        noteController = WebNoteController(note: nil, rootElement: nil)

        super.init()
        updateFavIcon(fromWebView: false)
    }

    private static func newBrowsingTree(origin: BrowsingTreeOrigin?) -> BrowsingTree {
        BrowsingTree(
            origin,
            frecencyScorer: ExponentialFrecencyScorer(storage: GRDBUrlFrecencyStorage()),
            longTermScoreStore: LongTermUrlScoreStore()
        )
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
        case isPinned
        case noteController
    }

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
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isFromNoteSearch = false

        originMode = .web
        super.init()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        if let originalQuery = originalQuery {
            try container.encode(originalQuery, forKey: .originalQuery)
        }
        if let currentURL = webView?.url {
            try container.encode(currentURL, forKey: .url)
        }
        var backForwardUrlList = [URL]()
        for backForwardListItem in webView?.backForwardList.backList ?? [] {
            backForwardUrlList.append(backForwardListItem.url)
        }
        try container.encode(backForwardUrlList, forKey: .backForwardUrlList)

        try container.encode(browsingTree, forKey: .browsingTree)
        try container.encode(privateMode, forKey: .privateMode)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(noteController, forKey: .noteController)
    }

    private func addTreeToNote() {
        if let rootId = browsingTree.rootId {
            noteController.noteOrDefault.browsingSessionIds.append(rootId)
        }
    }

    private func updateFocusedStateToElement(_ element: BeamElement) {
        guard let note = element.note ?? noteController.note else { return }
        state?.updateNoteFocusedState(note: note,
                                      focusedElement: element.id,
                                      cursorPosition: element.text.wholeRange.upperBound)
    }

    @discardableResult
    internal func logInNote(url: URL, title: String?, reason: NoteElementAddReason) -> BeamElement? {
        var elementToFocus: BeamElement?
        if isFromNoteSearch {
            noteController.setContents(url: url, text: title)
            isFromNoteSearch = false
            elementToFocus = noteController.element
        } else {
            elementToFocus = noteController.add(url: url, text: title, reason: reason, isNavigatingFromNote: beamNavigationController?.isNavigatingFromNote == true, browsingOrigin: self.browsingTree.origin)
        }
        if let elementToFocus = elementToFocus {
            updateFocusedStateToElement(elementToFocus)
            return elementToFocus
        } else {
            return nil
        }
    }

    private func receivedWebviewTitle(_ title: String? = nil) {
        self.title = title ?? ""
    }

    private var updateFavIconDispatchItem: DispatchWorkItem?
    func updateFavIcon(fromWebView: Bool, cacheOnly: Bool = false) {
        guard let url = url else { favIcon = nil; return }
        updateFavIconDispatchItem?.cancel()
        let dispatchItem = DispatchWorkItem { [weak self] in
            guard !fromWebView || cacheOnly || self?.webView != nil else { return }
            FaviconProvider.shared.favicon(fromURL: url, webView: fromWebView ? self?.webView : nil, cacheOnly: cacheOnly) { [weak self] (favicon) in
                guard let self = self else { return }
                guard let image = favicon?.image else {
                    if fromWebView {
                        // no favicon found from webview, try url instead.
                        self.updateFavIcon(fromWebView: false)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.favIcon = image
                }
            }
        }
        updateFavIconDispatchItem = dispatchItem
        let deadline: DispatchTime = .now() + .milliseconds(fromWebView && !cacheOnly ? 500 : 0)
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: dispatchItem)
    }

    func updateScore() {
        let score = browsingTree.current.score.score
//            Logger.shared.logDebug("updated score[\(url!.absoluteString)] = \(s)", category: .general)
        noteController.score = score
    }

    private func setupObservers() {
        if !scope.isEmpty {
            cancelObservers()
        }
        Logger.shared.logDebug("setupObservers", category: .javascript)
        webView.publisher(for: \.title)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [unowned self] value in
            self.receivedWebviewTitle(value)
        }.store(in: &scope)

        webView.publisher(for: \.url).sink { [unowned self] webviewUrl in
            guard let webviewUrl = webviewUrl else {
                return // webview probably failed to load
            }

            // For security reason, we shoud only update the URL from JS when the new one is from same origin
            // If the page is loading, we are not navigating through JS, so URL will be updated in webView(_, didCommit) in BeamWebNavigationController
            // https://github.com/mozilla-mobile/firefox-ios/wiki/WKWebView-navigation-and-security-considerations#single-page-js-apps-spas
            if !webView.isLoading, let url = url, webviewUrl.isSameOrigin(as: url) {
                self.url = webviewUrl
            }
        }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink { [unowned self] value in isLoading = value }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink { [unowned self] value in estimatedLoadingProgress = value }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent)
            .sink { [unowned self] value in hasOnlySecureContent = value }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink { [unowned self] value in serverTrust = value }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink { [unowned self] value in canGoBack = value }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink { [unowned self] value in canGoForward = value }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink { [unowned self] value in backForwardList = value }.store(in: &scope)

        webView.navigationDelegate = beamNavigationController
        webView.uiDelegate = uiDelegateController

        state?.$focusOmniBox.sink { [weak self] value in
            guard value else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                self?.pointAndShoot?.dismissActiveShootGroup()
            }
        }.store(in: &scope)
    }

    func cancelObservers() {
        Logger.shared.logDebug("cancelObservers", category: .javascript)
        scope.removeAll()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
    }

    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
    }

    public func load(url: URL) {
        guard !url.absoluteString.isEmpty else { return }
        hasError = false
        screenshotCapture = nil
        if !isFromNoteSearch {
            navigationController?.setLoading()
        }
        self.url = url
        requestedURL = url

        navigationCount = 0
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
        Logger.shared.logDebug("BrowserTab load \(url.absoluteString)", category: .passwordManagerInternal)
        passwordOverlayController?.prepareForLoading()
        $isLoading.sink { [unowned passwordOverlayController] loading in
            if !loading {
                Logger.shared.logDebug("BrowserTab finished loading \(url.absoluteString)", category: .passwordManagerInternal)
                passwordOverlayController?.webViewFinishedLoading()
            }
        }.store(in: &scope)

    }

    func postLoadSetup(state: BeamState) {
        self.state = state
        let web = BeamWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
        web.wantsLayer = true
        web.allowsMagnification = true

        state.setup(webView: web)
        backForwardList = web.backForwardList
        web.page = self

        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
        webView = web
        self.webView.page = self
        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
        addTreeToNote()
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
                self?.load(url: suppliedPreloadURL)
            }
        }
    }

    func reload() {
        hasError = false
        leave()
        if let webviewUrl = webView.url, BeamURL(webviewUrl).isErrorPage, let originalUrl = BeamURL(webviewUrl).originalURLFromErrorPage {
            webView.replaceLocation(with: originalUrl)
        } else if webView.url == nil, let url = url {
            load(url: url)
        } else {
            webView.reload()
        }
    }

    func stopLoad() {
        webView.stopLoading()
    }

    private var refocusDispatchItem: DispatchWorkItem?
    func tabDidAppear(withState newState: BeamState?) {
        if newState != state {
            if state == nil, let newState = newState {
                // first read on a lazy tab
                postLoadSetup(state: newState)
            } else {
                state = newState
            }
        }

        lastViewDate = BeamDate.now
        browsingTree.startReading()
        guard !isLoading && url != nil && state?.focusOmniBox != true else { return }
        // bring back the focus to where it was
        refocusDispatchItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let webView = self?.webView, self?.isActiveTab() == true, self?.state?.focusOmniBox == false else { return }
            webView.window?.makeFirstResponder(webView)
            webView.page?.executeJS("refocusLastElement()", objectName: "FocusHandling")
            self?.updateFavIcon(fromWebView: true)
        }
        refocusDispatchItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(200)), execute: workItem)
    }

    func switchToCard() {
        passwordOverlayController?.dismiss()
        browsingTree.switchToCard()
    }

    func switchToJournal() {
        passwordOverlayController?.dismiss()
        browsingTree.switchToJournal()
    }

    func switchToOtherTab() {
        passwordOverlayController?.dismiss()
        browsingTree.switchToOtherTab()
    }

    func willSwitchToNewUrl(url: URL) {
        isFromNoteSearch = false
        beamNavigationController?.isNavigatingFromNote = false
        if self.url != nil && url.mainHost != self.url?.mainHost {
            resetDestinationNote()
        }
    }

    func goBack() {
        hasError = false
        webView.goBack()
    }

    func goForward() {
        hasError = false
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
        state?.overlayViewModel.toastView = AnyView(CredentialsConfirmationToast(saved: saved))
    }

    func closeApp() {
        passwordOverlayController?.dismiss()
        authenticationViewModel?.cancel()
        browsingTree.closeApp()
        saveTree(grouped: true)
        sendTree(grouped: true)
    }

    private func resetDestinationNote() {
        noteController.setDestination(note: nil)
        state?.resetDestinationCard()
    }

    private func tabDidChangeWindow() {
        guard isPinned else { return }
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = false
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            self?.screenshotCapture = image
        }
    }

    internal func sendTree(grouped: Bool = false) {
        guard let sender = state?.data.browsingTreeSender else { return }
        if grouped {
            sender.groupSend(browsingTree: browsingTree)
        } else {
            sender.send(browsingTree: browsingTree)
        }
    }

    internal func saveTree(grouped: Bool = false) {
        guard let appSessionId = state?.data.sessionId else { return }
        if grouped {
            BrowsingTreeStoreManager.shared.groupSave(browsingTree: self.browsingTree, appSessionId: appSessionId)
        } else {
            BrowsingTreeStoreManager.shared.save(browsingTree: self.browsingTree, appSessionId: appSessionId) {}
        }
    }
}

// MARK: - WebPositionsDelegate
extension BrowserTab: WebPositionsDelegate {
    /// The callback triggered when WebPositions recieves an updated scroll position.
    /// Callback will be called very often. Take care of your own debouncing or throttling
    /// - Parameter frame: WebPage frame coordinates and positions
    func webPositionsDidUpdateScroll(with frame: WebPositions.FrameInfo) {
        passwordOverlayController?.updateScrollPosition(for: frame)
        guard let scorer = browsingScorer else { return }
        scorer.debouncedUpdateScrollingScore.send(frame)
    }
}
