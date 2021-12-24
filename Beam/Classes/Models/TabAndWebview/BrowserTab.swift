import Foundation
import SwiftUI
import Combine
import WebKit
import BeamCore
import Promises

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
@objc class BrowserTab: NSObject, ObservableObject, Identifiable, Codable, WebPage, Scorable {

    var id: UUID = UUID()

    var width: CGFloat = 0
    var height: CGFloat = 0
    private var pixelRatio: Double = 1

    let uiDelegateController = BeamWebkitUIDelegateController()
    let noteController: WebNoteController

    private var isFromNoteSearch: Bool = false

    public func load(url: URL) {
        guard !url.absoluteString.isEmpty else { return }
        hasError = false
        screenshotCapture = nil
        if !isFromNoteSearch {
            navigationController?.setLoading()
        }
        self.url = url
        if url.isDomain {
            userTypedDomain = url
        }
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
        Logger.shared.logDebug("BrowserTab load \(url.absoluteString)", category: .passwordManagerInternal)
        $isLoading.sink { [unowned passwordOverlayController] loading in
            if !loading {
                Logger.shared.logDebug("BrowserTab loading \(url.absoluteString)", category: .passwordManagerInternal)
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
    @Published var responseStatusCode: Int = 200
    @Published var userTypedDomain: URL?
    @Published var isLoading: Bool = false
    @Published var estimatedLoadingProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false

    @Published var serverTrust: SecTrust?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList!
    @Published var favIcon: NSImage?
    @Published var hasError: Bool = false {
        didSet {
            if !hasError {
                errorPageManager = nil
            }
        }
    }

    @Published var browsingTree: BrowsingTree
    @Published var privateMode = false
    @Published var isPinned = false
    @Published var screenshotCapture: NSImage?

    @Published var authenticationViewModel: AuthenticationViewModel?
    @Published var searchViewModel: SearchViewModel?
    @Published var errorPageManager: ErrorPageManager? {
        didSet {
            if errorPageManager != nil {
                hasError = true
            }
        }
    }

    var backForwardUrlList: [URL]?

    var originMode: Mode

    var pointAndShootInstalled: Bool = true
    var pointAndShootEnabled: Bool {
        state?.focusOmniBox != true
    }

    var allowsPictureInPicture: Bool {
        Self.webViewConfiguration.allowsPictureInPicture
    }

    func isActiveTab() -> Bool {
        self == state?.browserTabsManager.currentTab
    }

    func leave() {
        pointAndShoot?.leavePage()
        cancelSearch()
    }

    func shouldNavigateInANewTab(url: URL) -> Bool {
        return isPinned && self.url != nil && url.mainHost != self.url?.mainHost
    }

    func navigatedTo(url: URL, title: String?, reason: NoteElementAddReason) {
        logInNote(url: url, title: title, reason: reason)
        updateFavIcon(fromWebView: true)
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
            elementToFocus = noteController.add(url: url, text: title, reason: reason, isNavigatingFromNote: beamNavigationController?.isNavigatingFromNote == true, browsingOrigin: self.browsingTree.origin)
        }
        if let elementToFocus = elementToFocus {
            updateFocusedStateToElement(elementToFocus)
            return elementToFocus
        } else {
            return nil
        }
    }

    private func updateFocusedStateToElement(_ element: BeamElement) {
        guard let note = element.note ?? noteController.note else { return }
        state?.updateNoteFocusedState(note: note,
                                      focusedElement: element.id,
                                      cursorPosition: element.text.wholeRange.upperBound)
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

    lazy var webPositions: WebPositions? = {
        let webPositions = WebPositions()
        webPositions.delegate = self
        return webPositions
    }()

    private var _navigationController: BeamWebNavigationController?
    var navigationController: WebNavigationController? {
        beamNavigationController
    }

    private var beamNavigationController: BeamWebNavigationController? {
        guard _navigationController == nil else { return _navigationController }
        guard let webView = webView else { return nil }
        let navController = BeamWebNavigationController(browsingTree: browsingTree, noteController: noteController, webView: webView)
        navController.page = self
        _navigationController = navController
        return navController
    }

    @Published var mediaPlayerController: MediaPlayerController?

    weak var state: BeamState? {
        didSet {
            guard oldValue != nil && state != oldValue else { return }
            tabDidChangeWindow()
        }
    }

    public var score: Float {
        get { noteController.score }
        set { noteController.score = newValue }
    }

    var webviewWindow: NSWindow? {
        webView.window
    }

    var downloadManager: DownloadManager? {
        state?.data.downloadManager
    }

    var frame: NSRect {
        webView.frame
    }

    var fileStorage: BeamFileStorage? {
        BeamFileDBManager.shared
    }

    private func resetDestinationNote() {
        noteController.setDestination(note: nil)
        state?.resetDestinationCard()
    }

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        noteController.setDestination(note: note, rootElement: rootElement)
        state?.destinationCardName = note.title
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
        DispatchQueue.main.async {
            self.updateFavIcon(fromWebView: false)
        }
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
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isFromNoteSearch = false

        originMode = .web
        super.init()
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

    func addToNote(allowSearchResult: Bool, inSourceBullet: Bool = true) -> BeamElement? {
        guard let url = url else {
            Logger.shared.logError("Cannot get current URL", category: .general)
            return nil
        }
        guard allowSearchResult || SearchEngines.get(url) != nil else {
            Logger.shared.logWarning("Adding search results is not allowed", category: .web)
            return nil
        } // Don't automatically add search results

        if inSourceBullet {
            let element = noteController.addContent(url: url, text: title, reason: .pointandshoot)
            return element
        } else {
            let element = noteController.note
            return element
        }
    }
    private func addTreeToNote() {
        if let rootId = browsingTree.rootId {
            noteController.noteOrDefault.browsingSessionIds.append(rootId)
        }
    }

    private func receivedWebviewTitle(_ title: String? = nil) {
        guard let url = url else {
            return
        }
        logInNote(url: url, title: title, reason: .loading)
        self.title = title ?? ""
    }

    func updateFavIcon(fromWebView: Bool, cacheOnly: Bool = false) {
        guard let url = url else { favIcon = nil; return }
        FaviconProvider.shared.favicon(fromURL: url, webView: fromWebView ? webView : nil, cacheOnly: cacheOnly) { [weak self] (image) in
            guard let self = self else { return }
            guard image != nil || !fromWebView else {
                // no favicon found from webview, try url instead.
                self.updateFavIcon(fromWebView: false)
                return
            }
            DispatchQueue.main.async {
                self.favIcon = image
            }
        }
    }

    func updateScore() {
        let score = browsingTree.current.score.score
//            Logger.shared.logDebug("updated score[\(url!.absoluteString)] = \(s)", category: .general)
        noteController.score = score
    }

    /// Calls BeamNote to fetch a note from the documentManager
    /// - Parameter noteTitle: The title of the Note
    /// - Returns: The fetched note or nil if no note exists
    func getNote(fromTitle noteTitle: String) -> BeamNote? {
        return BeamNote.fetch(title: noteTitle)
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
        let clusteringManager = state?.data.clusteringManager
        let id = browsingTree.current.link
        clusteringManager?.addPage(id: id, parentId: nil, newContent: text)
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
                self?.pointAndShoot?.dismissShoot()
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

    private func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, state: BeamState) -> WebPage {
        let newWebView = BeamWebView(frame: NSRect(), configuration: configuration ?? Self.webViewConfiguration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let origin = BrowsingTreeOrigin.browsingNode(
            id: browsingTree.current.id,
            pageLoadId: browsingTree.current.events.last?.pageLoadId,
            rootOrigin: browsingTree.origin.rootOrigin
        )
        let newTab = state.addNewTab(origin: origin, setCurrent: setCurrent,
                                     note: noteController.note, element: beamNavigationController?.isNavigatingFromNote == true ? noteController.element : nil,
                                     url: targetURL, webView: newWebView)
        newTab.browsingTree.current.score.openIndex = navigationCount
        navigationCount += 1
        browsingTree.openLinkInNewTab()
        return newTab
    }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage? {
        guard let state = state else { return nil }
        if let currentTab = state.browserTabsManager.currentTab, !currentTab.isPinned && !setCurrent && state.browserTabsManager.currentTabGroupKey != currentTab.id {
            state.browserTabsManager.removeTabFromGroup(tabId: currentTab.id)
            state.browserTabsManager.createNewGroup(for: currentTab.id)
        }
        return createNewTab(targetURL, configuration, setCurrent: setCurrent, state: state)
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
            let newBeamWindow = AppDelegate.main.createWindow(frame: windowFrame, restoringTabs: false)
            let tab = createNewTab(targetURL, configuration, setCurrent: setCurrent, state: newBeamWindow.state)
            newWindow = newBeamWindow
            newWebView = tab.webView
        } else {
            // this is more likely a login window or something that should disappear at some point so let's create something transient:
            newWebView = BeamWebView(frame: NSRect(), configuration: configuration ?? Self.webViewConfiguration)
            newWebView.enableAutoCloseWindow = true
            newWebView.wantsLayer = true
            newWebView.allowsMagnification = true
            state?.setup(webView: newWebView)

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

    func closeTab() {
        isFromNoteSearch = false
        beamNavigationController?.isNavigatingFromNote = false
        passwordOverlayController?.dismiss()
        authenticationViewModel?.cancel()
        browsingTree.closeTab()
        saveTree()
        sendTree()
    }

    func closeApp() {
        passwordOverlayController?.dismiss()
        authenticationViewModel?.cancel()
        browsingTree.closeApp()
        saveTree(grouped: true)
        sendTree(grouped: true)
    }

    func collectTab() {

        guard let layer = webView.layer,
                let url = url,
                let pns = pointAndShoot
        else { return }

        let animator = FullPageCollectAnimator(webView: webView)
        guard let (hoverLayer, hoverGroup, webViewGroup) = animator.buildFullPageCollectAnimation() else { return }
        let webviewFrame = webView.frame

        let remover = LayerRemoverAnimationDelegate(with: hoverLayer) { _ in
            DispatchQueue.main.async {
                var webviewCenter = CGPoint(x: webviewFrame.midX, y: webviewFrame.midY)
                webviewCenter.x -= PointAndShootView.defaultPickerSize.width / 2
                webviewCenter.y -= PointAndShootView.defaultPickerSize.height / 2
                let mouseLocation = webviewFrame.contains(pns.mouseLocation) ? pns.mouseLocation : webviewCenter
                let target = PointAndShoot.Target.init(id: UUID().uuidString, rect: self.webView.frame, mouseLocation: mouseLocation, html: "<a href=\"\(url)\">\(self.title)</a>", animated: true)
                let shootGroup = PointAndShoot.ShootGroup.init(UUID().uuidString, [target], "", "", shapeCache: nil, showRect: false, directShoot: true)

                if let note = self.noteController.note {
                    pns.addShootToNote(targetNote: note, withNote: nil, group: shootGroup, withSourceBullet: false, completion: {})
                } else {
                    pns.activeShootGroup = shootGroup
                }
            }
        }
        hoverGroup.delegate = remover

        layer.superlayer?.addSublayer(hoverLayer)
        layer.add(webViewGroup, forKey: "animation")
        hoverLayer.add(hoverGroup, forKey: "hover")
    }

    private func tabDidChangeWindow() {
        guard isPinned else { return }
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = false
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            self?.screenshotCapture = image
        }
    }

    private func sendTree(grouped: Bool = false) {
        guard let sender = state?.data.browsingTreeSender else { return }
        if grouped {
            sender.groupSend(browsingTree: browsingTree)
        } else {
            sender.send(browsingTree: browsingTree)
        }
    }

    private func saveTree(grouped: Bool = false) {
        guard let appSessionId = state?.data.sessionId else { return }
        if grouped {
            BrowsingTreeStoreManager.shared.groupSave(browsingTree: self.browsingTree, appSessionId: appSessionId)
        } else {
            BrowsingTreeStoreManager.shared.save(browsingTree: self.browsingTree, appSessionId: appSessionId) {}
        }
    }
}

extension BrowserTab: WebPositionsDelegate {
    /// The callback triggered when WebPositions recieves an updated scroll position.
    /// Callback will be called very often. Take care of your own debouncing or throttling
    /// - Parameter frame: WebPage frame coordinates and positions
    func webPositionsDidUpdateScroll(with frame: WebPositions.FrameInfo) {
        guard let scorer = browsingScorer else { return }
        scorer.debouncedUpdateScrollingScore.send(frame)
    }
}
