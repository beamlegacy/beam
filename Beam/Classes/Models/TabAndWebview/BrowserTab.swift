import Foundation
import SwiftUI
import Combine
import WebKit
import BeamCore

@objc class BrowserTab: NSObject, ObservableObject, Identifiable, Codable {

    typealias TabID = UUID
    var id: TabID = TabID()
    override var description: String {
        "BrowserTab(\(!title.isEmpty ? title : (url?.absoluteString ?? super.description)))"
    }

    @Published var isLoading: Bool = false {
        didSet {
            if !isLoading, let url = url {
                Logger.shared.logDebug("BrowserTab finished loading \(url.absoluteString)", category: .webAutofillInternal)
                webAutofillController?.webViewFinishedLoading()
            }
        }
    }
    @Published var estimatedLoadingProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false

    @Published var serverTrust: SecTrust?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList!
    @Published var favIcon: NSImage?

    @Published var browsingTree: BrowsingTree
    @Published var privateMode = false
    @Published var isPinned = false {
        didSet {
            browsingTree.isPinned = isPinned
        }
    }
    @Published var screenshotCapture: NSImage?
    @Published var hasCopiedURL: Bool = false

    weak var state: BeamState? {
        didSet {
            guard oldValue != nil && state != oldValue else { return }
            tabDidChangeWindow()
        }
    }
    var data: BeamData { state?.data ?? BeamData.shared }
    var preloadUrl: URL?

    private var restoredInteractionState: Any?

    var interactionState: Any? {
        if #available(macOS 12.0, *) {
            return restoredInteractionState ?? webView.interactionState
        }
        return nil
    }

    var backForwardUrlList: [URL]?
    var originMode: Mode
    let uiDelegateController = BeamWebkitUIDelegateController()
    var webViewController: WebViewController?
    let noteController: WebNoteController
    internal var isFromNoteSearch: Bool = false
    var allowsPictureInPicture: Bool {
        BeamWebViewConfigurationBase.allowsPictureInPicture
    }

    var creationDate: Date = BeamDate.now
    var lastViewDate: Date = BeamDate.now

    private var observersCancellables = Set<AnyCancellable>()
    private var searchViewModelCancellable: AnyCancellable?

    static let webViewConfiguration = BeamWebViewConfigurationBase(handlers: handlers(isIncognito: false))

    static var incognitoWebViewConfiguration: BeamWebViewConfigurationBase {
        BeamWebViewConfigurationBase(handlers: handlers(isIncognito: true), isIncognito: true)
    }

    private static func handlers(isIncognito: Bool) -> [SimpleBeamMessageHandler] {
        var handlers = [
            WebPositionsMessageHandler(),
            PointAndShootMessageHandler(),
            JSNavigationMessageHandler(),
            MediaPlayerMessageHandler(),
            GeolocationMessageHandler(),
            WebSearchMessageHandler(),
            MouseOverAndSelectionMessageHandler(),
            ContextMenuMessageHandler()
        ]
        if !isIncognito {
            handlers.append(contentsOf: [
                LoggingMessageHandler(),
                WebAutofillMessageHandler()
            ])
        }
        return handlers
    }

    var browsingTreeOrigin: BrowsingTreeOrigin?

    var showsStatusBar: Bool {
        guard PreferencesManager.showsStatusBar else { return false }
        switch mouseHoveringLocation {
        case .none: return false
        case .link: return true
        }
    }

    // MARK: - WebPage properties

    /// Content View container of the tab. WebKit can insert content to the parent of the ``webView`` so we need to hold it.
    private(set) var contentView: NSViewContainerView<BeamWebView>
    /// The raw ``BeamWebView`` managed by the tab. For display purposes, prefer to use ``contentView``.
    @Published private(set) var webView: BeamWebView {
        didSet {
            observeWebView()
        }
    }
    var webviewWindow: NSWindow? { webView.window }
    var frame: NSRect { webView.frame }

    var searchViewModel: SearchViewModel? {
        didSet {
            searchViewModelCancellable?.cancel()
            searchViewModelCancellable = searchViewModel?.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    @Published var title: String = ""
    @Published var originalQuery: String?
    @Published var url: URL?

    @Published var contentDescription: BrowserContentDescription?
    @Published var authenticationViewModel: AuthenticationViewModel?
    @Published var mouseHoveringLocation: MouseHoveringLocation = .none
    @Published var textSelection: String?
    @Published var pendingContextMenuPayload: ContextMenuMessageHandlerPayload?
    @Published var responseStatusCode: Int = 200
    @Published var isDetachable: Bool = false
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
    var fileStorage: BeamFileStorage? { data.fileDBManager }
    var downloadManager: DownloadManager? {
        data.downloadManager
    }

    var webViewNavigationHandler: WebViewNavigationHandler? {
        webViewController
    }

    lazy var webAutofillController: WebAutofillController? = {
        guard let state = state else { return nil }
        let controller = WebAutofillController(passwordManager: state.data.passwordManager, userInfoStore: MockUserInformationsStore.shared)
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
        contentType == .web && state?.omniboxInfo.isFocused != true && state?.associatedWindow?.isKeyWindow == true
    }
    var webFrames = WebFrames()
    var webPositions: WebPositions

    var numberOfLinksOpenedInANewTab: Int = 0

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
    init(state: BeamState,
         browsingTreeOrigin: BrowsingTreeOrigin?,
         originMode: Mode,
         note: BeamNote?,
         rootElement: BeamElement? = nil,
         id: UUID = UUID(),
         webView: BeamWebView? = nil,
         interactionState: Any? = nil) {
        self.state = state
        self.id = id
        self.browsingTreeOrigin = browsingTreeOrigin
        self.originMode = originMode
        isFromNoteSearch = rootElement != nil

        if let suppliedWebView = webView {
            self.webView = suppliedWebView
            self.contentView = NSViewContainerView(contentView: suppliedWebView)
            backForwardList = suppliedWebView.backForwardList
        } else {
            let beamWebView = BeamWebView(
                frame: .zero,
                configuration: state.isIncognito ? BrowserTab.incognitoWebViewConfiguration : BrowserTab.webViewConfiguration
            )
            self.webView = beamWebView
            self.contentView = NSViewContainerView(contentView: beamWebView)
        }
        browsingTree = Self.newBrowsingTree(origin: browsingTreeOrigin, isIncognito: state.isIncognito)
        noteController = WebNoteController(note: note, rootElement: rootElement, data: state.data)
        webPositions = WebPositions(webFrames: webFrames)
        super.init()
        webPositions.delegate = self

        if webView == nil {
            self.webView.wantsLayer = true
            self.webView.allowsMagnification = true
            state.setup(webView: self.webView)
            backForwardList = self.webView.backForwardList
        }

        self.webView.page = self
        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
        addTreeToNote()
        observeWebView()

        if #available(macOS 12.0, *), let state = interactionState {
            self.webView.interactionState = state
        }
    }

    init(pinnedTabWithId id: UUID, url: URL, title: String) {
        self.id = id
        self.url = url
        self.preloadUrl = url
        self.title = title
        self.isPinned = true
        self.originMode = .web

        let beamWebView = BeamWebView(frame: .zero, configuration: BrowserTab.webViewConfiguration)
        self.webView = beamWebView
        self.contentView = NSViewContainerView(contentView: beamWebView)

        browsingTree = Self.newBrowsingTree(origin: .pinnedTab(url: url), isIncognito: false)
        noteController = WebNoteController(note: nil, rootElement: nil, data: nil)
        webPositions = WebPositions(webFrames: webFrames)
        super.init()
        webPositions.delegate = self
        browsingTree.isPinned = true
        updateFavIcon(fromWebView: false)
    }

    private static func newBrowsingTree(origin: BrowsingTreeOrigin?, isIncognito: Bool) -> BrowsingTree {
        if isIncognito {
            return BrowsingTree.incognitoBrowsingTree(origin: origin)
        } else {
            return BrowsingTree(
                origin,
                linkStore: LinkStore.shared,
                frecencyScorer: ExponentialFrecencyScorer(storage: LinkStoreFrecencyUrlStorage(objectManager: BeamData.shared.objectManager)),
                domainPath0TreeStatsStore: DomainPath0TreeStatsStorage(),
                dailyScoreStore: GRDBDailyUrlScoreStore()
            )
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalQuery
        case url
        case interactionState
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
        backForwardUrlList = try? container.decode([URL].self, forKey: .backForwardUrlList)
        if #available(macOS 12.0, *), let interactionState = try? container.decode(Data.self, forKey: .interactionState) {
            restoredInteractionState = interactionState
        }

        let tree: BrowsingTree = try container.decode(BrowsingTree.self, forKey: .browsingTree)
        browsingTree = tree
        noteController = try container.decode(WebNoteController.self, forKey: .noteController)
        privateMode = try container.decode(Bool.self, forKey: .privateMode)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isFromNoteSearch = false

        originMode = .web

        let beamWebView = BeamWebView(frame: .zero, configuration: BrowserTab.webViewConfiguration)
        webView = beamWebView
        contentView = NSViewContainerView(contentView: beamWebView)
        webPositions = WebPositions(webFrames: webFrames)
        super.init()
        tree.set(
            frecencyScorer: ExponentialFrecencyScorer(storage: LinkStoreFrecencyUrlStorage(objectManager: data.objectManager)),
            domainPath0TreeStatsStore: DomainPath0TreeStatsStorage(),
            dailyScoreStore: GRDBDailyUrlScoreStore()
        )
        webPositions.delegate = self
        updateFavIcon(fromWebView: false)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        if let originalQuery = originalQuery {
            try container.encode(originalQuery, forKey: .originalQuery)
        }
        if let currentURL = webView.url ?? preloadUrl {
            try container.encode(currentURL, forKey: .url)
        }

        if #available(macOS 12.0, *), let interactionStateData = interactionState as? Data {
            try container.encode(interactionStateData, forKey: .interactionState)
        } else {
            let backForwardUrlList: [URL] = webView.backForwardList.backList.map { $0.url }
            try container.encode(backForwardUrlList, forKey: .backForwardUrlList)
        }

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
        let position = element.text.wholeRange.upperBound
        state?.updateNoteFocusedState(note: note,
                                      focusedElement: element.id,
                                      cursorPosition: position,
                                      selectedRange: position..<position,
                                      isReference: false,
                                      nodeSelectionState: nil)
    }

    internal func logInNote(url: URL, reason: NoteElementAddReason) {
        Task {
            // Add url to note based on NoteSearch
            if isFromNoteSearch, case .searchFromNode(let search) = browsingTreeOrigin, let search = search {
                isFromNoteSearch = false
                await noteController.replaceSearchWithSearchLink(search, url: url)
            } else {
                if let elementToFocus = await noteController.addLink(
                    url: url,
                    reason: reason,
                    isNavigatingFromNote: isFromNoteSearch,
                    browsingOrigin: self.browsingTree.origin
                ) {
                    updateFocusedStateToElement(elementToFocus)
                }
            }
        }
    }

    private var updateFavIconDispatchItem: DispatchWorkItem?
    func updateFavIcon(fromWebView: Bool, cacheOnly: Bool = false, clearIfNotFound: Bool = false) {
        guard let url = (url ?? preloadUrl) else { favIcon = nil; return }
        updateFavIconDispatchItem?.cancel()
        let dispatchItem = DispatchWorkItem { [weak self] in
            let isLoading = self?.isLoading == true || self?.webView.isLoading == true
            let policy: FaviconProvider.CachePolicy = cacheOnly ? .cacheOnly : .default
            guard !fromWebView || cacheOnly || (self?.webView != nil && !isLoading), let provider = self?.data.faviconProvider else { return }
            provider.favicon(fromURL: url, webView: fromWebView ? self?.webView : nil, cachePolicy: policy) { [weak self] (favicon) in
                guard let self = self else { return }
                guard let image = favicon?.image else {
                    if clearIfNotFound {
                        DispatchQueue.main.async {
                            self.favIcon = nil
                        }
                    } else if fromWebView {
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

    private func setupWebViewController() {
        webViewController = WebViewController(with: webView)
        webViewController?.delegate = self
        webViewController?.page = self
    }

    private func observeWebView() {
        if !observersCancellables.isEmpty {
            cancelObservers()
        }
        Logger.shared.logDebug("observeWebView", category: .web)

        setupWebViewController()

        webView.uiDelegate = uiDelegateController

        state?.$omniboxInfo.sink { [weak self] value in
            guard value.isFocused else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                self?.pointAndShoot?.dismissActiveShootGroup()
            }
        }.store(in: &observersCancellables)

        PreferencesManager.$isTabToHighlightOn.sink { [unowned self] newValue in
            self.webView.configurationWithoutMakingCopy.preferences.tabFocusesLinks = newValue
        }.store(in: &observersCancellables)
    }

    func cancelObservers() {
        Logger.shared.logDebug("cancelObservers", category: .web)

        observersCancellables.removeAll()
        webViewController = nil
        webView.uiDelegate = nil
    }

    func removeFromWindow() {
        state?.browserTabsManager.removeTab(tabId: id)
    }

    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
    }

    /// Defer to the VideoCallManager to check for the receiver if a received alert should be switched.
    /// - Parameters:
    ///   - message: the message shown within the original alert.
    ///   - frameInfo: the ``WKFrameInfo`` of the original alert.
    ///   - defaultAlertHandler: A handler in case where no alert replacement is provided and default alert should be shown.
    ///   - completionHandler: The completion handler to call **in any case**.
    func interceptJavaScriptAlert(
        with message: String,
        frameInfo: WKFrameInfo,
        defaultAlertHandler: @escaping () -> Void,
        completionHandler: @escaping () -> Void
    ) {
        if let videoCallsManager = state?.videoCallsManager {
            videoCallsManager.switchJavaScriptAlertIfNecessary(with: message, frameInfo: frameInfo) { [weak self] context in
                // If we do need to switch the alert and we have a context (alert+meeting), present the alert and handle feedback
                if let (alert, meeting) = context, let self = self {
                    let response = alert.runModal()
                    let shouldAutoJoin = response == .alertFirstButtonReturn
                    if shouldAutoJoin {
                        do {
                            try self.state?.videoCallsManager.autoJoinMeeting(meeting, faviconProvider: self.data.faviconProvider)
                        } catch {
                            UserAlert.showError(error: error)
                        }
                    }
                    // don't forget to call completionHandler
                    completionHandler()
                } else {
                    defaultAlertHandler()
                    completionHandler()
                }
            }
        } else {
            defaultAlertHandler()
            completionHandler()
        }
    }

    func openAsSideWindowIfEligible(request: URLRequest) -> Bool {
        guard let manager = state?.videoCallsManager else { return false }
        let currentURLIsNotEligible = !manager.isEligible(tab: self)
        let requestIsEligible = request.url.map { manager.isEligible(url: $0) } ?? false
        guard PreferencesManager.videoCallsAlwaysInSideWindow, requestIsEligible, currentURLIsNotEligible else { return false }
        do {
            try manager.start(with: request, faviconProvider: data.faviconProvider, bounceIfExistingSession: false)
            return true
        } catch let err as VideoCallsManager.Error {
            Logger.shared.logInfo("Could not open video call link \(err)", category: .general)
        } catch {
            Logger.shared.logError("An error occured when opening video call link", category: .general)
        }
        return false
    }

    /// Loads a request to webView.
    /// - Parameters:
    ///   - request: the request to load.
    ///   - entirely: performs entirely the request, defaults to `true`.
    ///   If ``BeamWebView`` is already loaded and you just want to fetch associated info to the request, set this to `false`.
    public func load(request: URLRequest, entirely: Bool = true) {
        guard let url = request.url else { return }

        if entirely, openAsSideWindowIfEligible(request: request) {
            return
        }

        hasError = false
        screenshotCapture = nil
        if !isFromNoteSearch, !browsingTree.justCreatedFromOtherTab {
            webViewController?.webViewIsInstructedToLoadURLFromUI(url)
        }
        self.url = url

        numberOfLinksOpenedInANewTab = 0
        if entirely {
            if url.isFileURL {
                let mayLoadLocalResources = BeamUniformTypeIdentifiers.urlMayLoadLocalResources(url)
                webView.loadFileURL(url, allowingReadAccessTo: mayLoadLocalResources ? url.deletingLastPathComponent() : url)
            } else {
                webView.load(request)
            }
        } else {
            webViewController?.webView(webView, didReachURL: url)
            webViewController?.webView(webView, didFinishNavigationToURL: url, source: .webKit)
        }

        Logger.shared.logDebug("BrowserTab load \(url.absoluteString)", category: .webAutofillInternal)
        webAutofillController?.prepareForLoading()
    }

    /// Called when doing CMD+Shift+T to create a tab that has been closed and when
    /// a pinned Tab is first displayed (called from tabDidAppear)
    /// - Parameter state: BeamState
    func postLoadSetup(state: BeamState) {
        // The webview is created in the init, but we want to set it up with a specific beamstate
        state.setup(webView: webView)
        self.state = state
        self.webView.page = self
        self.webView.wantsLayer = true
        self.webView.allowsMagnification = true
        self.backForwardList = self.webView.backForwardList

        uiDelegateController.page = self
        mediaPlayerController = MediaPlayerController(page: self)
        addTreeToNote()
        observeWebView()

        // Reload the state and url
        if #available(macOS 12.0, *), let restoredInteractionState = restoredInteractionState {
            self.webView.interactionState = restoredInteractionState
            self.url = webView.url
        } else {
            // This doesn't really work. We could manipulate history with JS like Firefox does
            // https://github.com/mozilla-mobile/firefox-ios/wiki/History-Restoration-in-WKWebView-(and-Error-Pages)
            backForwardUrlList?.forEach { url in
                self.webView.load(URLRequest(url: url))
            }
            if let suppliedPreloadURL = preloadUrl {
                DispatchQueue.main.async { [weak self] in
                    self?.load(request: URLRequest(url: suppliedPreloadURL))
                }
            }
        }
        restoredInteractionState = nil
        backForwardUrlList = nil
        preloadUrl = nil
    }

    fileprivate func tabWillLeaveCurrentPage() {
        mediaPlayerController = .init(page: self)
        webAutofillController?.dismiss()
        pointAndShoot?.leavePage()
        mouseHoveringLocation = .none
        cancelSearch()
        updateFavIcon(fromWebView: false, cacheOnly: true, clearIfNotFound: true)
    }

    func reload(configureWebViewWithAdBlocker: Bool = true) {
        hasError = false
        tabWillLeaveCurrentPage()
        if configureWebViewWithAdBlocker {
            ContentBlockingManager.shared.configure(webView: webView)
        }
        if let webviewUrl = webView.url, BeamURL(webviewUrl).isErrorPage, let originalUrl = BeamURL(webviewUrl).originalURLFromErrorPage {
            webView.replaceLocation(with: originalUrl)
        } else if webView.url == nil, let url = url {
            load(request: URLRequest(url: url))
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
        guard !isLoading && url != nil &&
                state?.omniboxInfo.isFocused != true && pointAndShoot?.activeShootGroup == nil else { return }
        // bring back the focus to where it was
        refocusDispatchItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard self?.isActiveTab() == true, self?.state?.omniboxInfo.isFocused == false else { return }
            self?.makeFirstResponder()
            self?.updateFavIcon(fromWebView: true)
        }
        refocusDispatchItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(200)), execute: workItem)
    }

    func makeFirstResponder() {
        guard webView.window?.isMainWindow == true else { return }
        webView.window?.makeFirstResponder(webView)
    }

    func switchToCard() {
        webAutofillController?.dismiss()
        browsingTree.switchToCard()
    }

    func switchToJournal() {
        webAutofillController?.dismiss()
        browsingTree.switchToJournal()
    }

    func switchToOtherTab() {
        webAutofillController?.dismiss()
        browsingTree.switchToOtherTab()
    }

    func willSwitchToNewUrl(url: URL?) {
        isFromNoteSearch = false
        if self.url != nil && url?.mainHost != self.url?.mainHost {
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
        webAutofillController?.dismiss()
        browsingTree.switchToBackground()
    }

    func dumpBrowsingTree() {
        browsingTree.dump()
    }

    func shouldHijackEscapeKey() -> Bool {
        webAutofillController?.isPresentingOverlay == true
    }

    func respondToEscapeKey() {
        webAutofillController?.dismiss()
        searchViewModel?.close()
    }

    func passwordManagerToast(saved: Bool) {
        state?.overlayViewModel.toastView = AnyView(CredentialsConfirmationToast(saved: saved))
    }

    func appWillClose() {
        cancelObservers()
        webAutofillController?.dismiss()
        authenticationViewModel?.cancel()
        browsingTree.closeApp()
        saveTree(grouped: true)
    }

    func pin() {
        browsingTree.tabPin()
    }
    func unPin() {
        browsingTree.tabUnpin()
    }
    func pinSuggest() {
        browsingTree.tabPinSuggest()
    }

    private func resetDestinationNote() {
        noteController.resetDestinationNote()
        state?.resetDestinationCard()
    }

    private func tabDidChangeWindow() {
        guard isPinned else { return }
        Task {
            await updateTabScreenshot()
        }
    }

    /// Takes a screenshot of the webpage and updates the screenshotCapture property of the BrowserTab
    @MainActor
    func updateTabScreenshot() async {
        self.screenshotCapture = await screenshotTab()
    }

    /// Screenshot the current tab
    /// - Returns: NSImage of the current tab if screenshot is successful
    @MainActor
    func screenshotTab() async -> NSImage? {
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        let snapshot = try? await webView.takeSnapshot(configuration: config)
        guard snapshot?.isValid == true else { return nil }
        return snapshot
    }

    internal func sendTree(grouped: Bool = false) {
        guard let state = state, !state.isIncognito else { return }
        guard let sender = state.data.browsingTreeSender else { return }
        if grouped {
            sender.groupSend(browsingTree: browsingTree)
        } else {
            sender.send(browsingTree: browsingTree)
        }
    }

    internal func saveTree(grouped: Bool = false) {
        guard let state = state, !state.isIncognito else { return }
        let appSessionId = state.data.sessionId
        if grouped {
            state.data.browsingTreeStoreManager.groupSave(browsingTree: self.browsingTree, appSessionId: appSessionId)
        } else {
            state.data.browsingTreeStoreManager.save(browsingTree: self.browsingTree, appSessionId: appSessionId) {}
        }
    }

    /// Writes the url the pasteboard in the following format: `<url title> - <minimizedHost>` where
    /// `<url title>` is a link pointing to the url
    /// `<minimizedHost>` is a link pointing to the minimizedHost url.
    ///
    /// It will first write the plain title to the pasteboard. Then it will fetch the page title
    /// from the proxy-api, clear and set the pasteboard with the correct title.
    ///
    /// - Parameters:
    ///   - url: url to write to pasteboard
    ///   - fetchTitle: automatically/asynchronously fetch the page's title and add it in the pasteboard
    private func writeURLToPasteboard(url: URL, fetchTitle: Bool = true) {

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let urlString = url.absoluteString
        pasteboard.setString(urlString, forType: .string)

        guard fetchTitle else { return }
        Task.detached(priority: .background) {
            let fetchedTitle = await WebNoteController.convertURLToBeamTextLink(url: url)
            let pasteboard = NSPasteboard.general
            guard pasteboard.string(forType: .string) == urlString else { return }
            let bTextHolder = BeamTextHolder(bText: fetchedTitle)
            let beamTextData = try PropertyListEncoder().encode(bTextHolder)
            pasteboard.setData(beamTextData, forType: .bTextHolder)
        }
    }

    func copyURLToPasteboard() {
        guard let url = url ?? preloadUrl else { return }

        // First write the plain url to the pasteboard
        writeURLToPasteboard(url: url)

        guard !hasCopiedURL else {
            // if it was already copied, let's dismiss right away.
            hasCopiedURL = false
            return
        }
        hasCopiedURL = true
        SoundEffectPlayer.shared.playSound(.beginRecord)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            self?.hasCopiedURL = false
        }
    }

    enum ZoomType { case `in`, out, reset }
    func zoom(_ type: ZoomType) {
        let pdfState = (contentDescription as? PDFContentDescription)?.contentState
        switch type {
        case .in:
            pdfState?.zoomIn()
            webView.zoomIn()
        case .out:
            pdfState?.zoomOut()
            webView.zoomOut()
        case .reset:
            pdfState?.scaleToActualSize()
            webView.zoomReset()
        }
    }
}

// MARK: - WebPositionsDelegate
extension BrowserTab: WebPositionsDelegate {
    /// The callback triggered when WebPositions receives an updated scroll position.
    /// Callback will be called very often. Take care of your own debouncing or throttling
    /// - Parameter frame: WebPage frame coordinates and positions
    func webPositionsDidUpdateScroll(with frame: WebFrames.FrameInfo) {
        webAutofillController?.updateScrollPosition(for: frame)
        guard let scorer = browsingScorer else { return }
        scorer.debouncedUpdateScrollingScore.send(frame)
    }

    /// The callback triggered when WebPositions receives an updated frame size.
    /// Callback will be called very often. Take care of your own debouncing or throttling
    /// - Parameter frame: WebPage frame coordinates and positions
    func webPositionsDidUpdateSize(with frame: WebFrames.FrameInfo) {
        webAutofillController?.updateScrollPosition(for: frame)
    }
}

// MARK: - WebViewController Delegate
extension BrowserTab: WebViewControllerDelegate {

    func webViewController(_ controller: WebViewController, didChangeDisplayURL url: URL) {
        self.url = url
    }

    func webViewController(_ controller: WebViewController, willMoveInHistory forward: Bool) {
        if forward {
            browsingTree.goForward()
        } else {
            browsingTree.goBack()
        }
        tabWillLeaveCurrentPage()
    }

    func webViewControllerIsNavigatingToANewPage(_ controller: WebViewController) {
        tabWillLeaveCurrentPage()
    }

    func webViewController(_ controller: WebViewController, didFinishNavigatingToPage navigationDescription: WebViewNavigationDescription) {
        let url = navigationDescription.url
        let isLinkActivation = navigationDescription.isLinkActivation

        updateFavIcon(fromWebView: true)
        isDetachable = state?.videoCallsManager.isEligible(tab: self) == true
        if isLinkActivation {
            pointAndShoot?.leavePage()
        }

        if case .searchFromNode = browsingTreeOrigin {
            logInNote(url: url, reason: isLinkActivation ? .navigation : .loading)
        }

        var shouldWaitForBetterContent = false
        if case .javascript = navigationDescription.source {
            shouldWaitForBetterContent = true
        }

        if !BeamURL(url).isErrorPage {
            state?.webIndexingController?.tabDidNavigate(self, toURL: url, originalRequestedURL: navigationDescription.requestedURL,
                                                         shouldWaitForBetterContent: shouldWaitForBetterContent,
                                                         isLinkActivation: isLinkActivation,
                                                         backwardNavigation: navigationDescription.isBackwardNavigation,
                                                         keepSameParent: navigationDescription.keepSameParent,
                                                         currentTab: state?.browserTabsManager.currentTab)
            state?.browserTabsManager.tabDidFinishNavigating(self, url: url)
        }
    }

    func webViewController(_ controller: WebViewController, didChangeLoadedContentType contentDescription: BrowserContentDescription?) {
        self.contentDescription = contentDescription
    }

    func webViewController<Value>(_ controller: WebViewController, observedValueChangedFor keyPath: KeyPath<WKWebView, Value>, value: Value) {
        switch keyPath {
        case \.title:
            self.title = value as? String ?? self.title
        case \.hasOnlySecureContent:
            self.hasOnlySecureContent = value as? Bool ?? self.hasOnlySecureContent
        case \.serverTrust:
            self.serverTrust = (value as! SecTrust?)
        case \.canGoBack:
            self.canGoBack = value as? Bool ?? self.canGoBack
        case \.canGoForward:
            self.canGoForward = value as? Bool ?? self.canGoForward
        case \.backForwardList:
            self.backForwardList = value as? WKBackForwardList ?? self.backForwardList
        case \.isLoading:
            self.isLoading = value as? Bool ?? self.isLoading
        case \.estimatedProgress:
            self.estimatedLoadingProgress = value as? Double ?? self.estimatedLoadingProgress
        case \.url:
            break // no-op. see webViewController:didChangeDisplayURL:
        default:
            break
        }
    }
}
