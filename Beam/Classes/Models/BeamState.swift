//
//  BeamState.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//
// swiftlint:disable file_length type_body_length

import Foundation
import Combine
import WebKit
import SwiftSoup
import BeamCore
import Sentry

@objc public class BeamState: NSObject, ObservableObject, Codable {
    var data: BeamData
    private let searchEngine: SearchEngineDescription = PreferredSearchEngine()

    @Published var currentNote: BeamNote? {
        didSet {
            EventsTracker.logBreadcrumb(message: "currentNote changed to \(String(describing: currentNote))", category: "BeamState")
            if let note = currentNote {
                recentsManager.currentNoteChanged(note)
            }
            stopFocusOmnibox()
        }
    }

    @Published var journalNoteToFocus: BeamNote? {
        didSet {
            EventsTracker.logBreadcrumb(message: "current journal Note to focus changed to \(String(describing: currentNote))", category: "BeamState")
            if let note = currentNote {
                recentsManager.currentNoteChanged(note)
            }
            stopFocusOmnibox()
        }
    }

    private(set) lazy var recentsManager: RecentsManager = {
        RecentsManager(with: DocumentManager())
    }()
    private(set) lazy var autocompleteManager: AutocompleteManager = {
        AutocompleteManager(searchEngine: searchEngine, beamState: self)
    }()
    private(set) lazy var browserTabsManager: BrowserTabsManager = {
        let manager = BrowserTabsManager(with: data, state: self)
        manager.delegate = self
        return manager
    }()
    private(set) lazy var noteMediaPlayerManager: NoteMediaPlayerManager = {
        NoteMediaPlayerManager()
    }()

    private(set) lazy var webIndexingController: WebIndexingController = {
        WebIndexingController(clusteringManager: data.clusteringManager)
    }()

    @Published var backForwardList = NoteBackForwardList()
    @Published var notesFocusedStates = NoteEditFocusedStateStorage()
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var omniboxInfo = OmniboxLayoutInformation()

    @Published var showHelpAndFeedback = false

    @Published var destinationCardIsFocused = false
    @Published var destinationCardName: String = ""
    @Published var destinationCardNameSelectedRange: Range<Int>?
    var keepDestinationNote = false

    var associatedWindow: NSWindow? {
        AppDelegate.main.windows.first { $0.state === self }
    }

    @Published var mode: Mode = .today {
        didSet {
            EventsTracker.logBreadcrumb(message: "mode changed to \(mode)", category: "BeamState")
            browserTabsManager.updateTabsForStateModeChange(mode, previousMode: oldValue)
            updateCanGoBackForward()

            stopFocusOmnibox()
            if oldValue == .today {
                stopShowingOmniboxInJournal()
            }

            if let leavingNote = currentNote, leavingNote.publicationStatus.isPublic, leavingNote.shouldUpdatePublishedVersion {
                BeamNoteSharingUtils.makeNotePublic(leavingNote, becomePublic: true)
            }
        }
    }

    var cachedJournalScrollView: NSScrollView?
    var cachedJournalStackView: JournalSimpleStackView?
    @Published var journalScrollOffset: CGFloat = 0
    var lastScrollOffset = [UUID: CGFloat]()

    @Published var currentPage: WindowPage?
    @Published var overlayViewModel: OverlayViewCenterViewModel = OverlayViewCenterViewModel()

    var shouldDisableLeadingGutterHover: Bool = false

    weak var currentEditor: BeamTextEdit?
    var editorShouldAllowMouseEvents: Bool {
        overlayViewModel.modalView == nil
    }
    var editorShouldAllowMouseHoverEvents: Bool {
        !omniboxInfo.isFocused
    }
    var isShowingOnboarding: Bool {
        data.onboardingManager.needsToDisplayOnboard
    }

    var downloadButtonPosition: CGPoint?

    private var scope = Set<AnyCancellable>()
    let cmdManager = CommandManager<BeamState>()

    func goBack() {
        guard canGoBack else { return }
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        switch mode {
        case .note, .page, .today:
            if let back = backForwardList.goBack() {
                switch back {
                case .journal:
                    navigateToJournal(note: nil)
                case let .note(note):
                    navigateToNote(note)
                case let .page(page):
                    navigateToPage(page)
                }
            }
        case .web:
            currentTab?.goBack()
        }

        updateCanGoBackForward()
    }

    func goForward() {
        guard canGoForward else { return }
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        switch mode {
        case .note, .page, .today:
            if let forward = backForwardList.goForward() {
                switch forward {
                case .journal:
                    navigateToJournal(note: nil)
                case let .note(note):
                    navigateToNote(note)
                case let .page(page):
                    navigateToPage(page)
                }
            }
        case .web:
            currentTab?.goForward()
        }

        updateCanGoBackForward()
    }

    func toggleBetweenWebAndNote() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        switch mode {
        case .web:
            let noteController = currentTab?.noteController
            if currentTab?.originMode != .note, let note = noteController?.note, note.type.isJournal {
                navigateToJournal(note: note)
            } else if let note = noteController?.note ?? currentNote {
                navigateToNote(note)
            } else {
                navigateToJournal(note: nil)
            }
        case .today, .note, .page:
            if hasBrowserTabs {
                mode = .web
            } else {
                startNewSearch()
            }
        }
    }

    func updateCanGoBackForward() {
        switch mode {
        case .today, .note, .page:
            canGoBack = !backForwardList.backList.isEmpty
            canGoForward = !backForwardList.forwardList.isEmpty
        case .web:
            canGoBack = currentTab?.canGoBack ?? false
            canGoForward = currentTab?.canGoForward ?? false
        }
    }

    @available(*, deprecated, message: "Using title might navigate to a different note if multiple databases, use ID if possible.")
    @discardableResult func navigateToNote(named: String, elementId: UUID? = nil) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) named \(named) - elementId \(String(describing: elementId))", category: "BeamState")
        //Logger.shared.logDebug("load note named \(named)")
        let note = BeamNote.fetchOrCreate(title: named)
        return navigateToNote(note, elementId: elementId)
    }

    @discardableResult func navigateToNote(id: UUID, elementId: UUID? = nil, unfold: Bool = false) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) id \(id) - elementId \(String(describing: elementId))", category: "BeamState")
        //Logger.shared.logDebug("load note named \(named)")
        guard let note = BeamNote.fetch(id: id, includeDeleted: false) else {
            return false
        }
        return navigateToNote(note, elementId: elementId, unfold: unfold)
    }

    @discardableResult func navigateToNote(_ note: BeamNote, elementId: UUID? = nil, unfold: Bool = false) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) \(note) - elementId \(String(describing: elementId))", category: "BeamState")
        mode = .note

        guard note != currentNote else { return true }

        note.sources.refreshScores {}
        data.noteFrecencyScorer.update(id: note.id, value: 1.0, eventType: .noteVisit, date: BeamDate.now, paramKey: .note30d0)
        data.noteFrecencyScorer.update(id: note.id, value: 1.0, eventType: .noteVisit, date: BeamDate.now, paramKey: .note30d1)
        currentPage = nil
        currentNote = note
        if let elementId = elementId {
            notesFocusedStates.currentFocusedState = NoteEditFocusedState(elementId: elementId, cursorPosition: 0, highlight: true, unfold: unfold)
        } else {
            notesFocusedStates.currentFocusedState = notesFocusedStates.getSavedNoteFocusedState(noteId: note.id)
        }

        backForwardList.push(.note(note))
        updateCanGoBackForward()
        return true
    }

    @discardableResult func navigateToJournal(note: BeamNote?, clearNavigation: Bool = false) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: note))", category: "BeamState")
        if mode == .today, note == nil {
            self.cachedJournalStackView?.scrollToTop(animated: true)
            return true
        }

        mode = .today

        currentPage = nil
        currentNote = nil

        if clearNavigation {
            backForwardList.clear()
        }
        backForwardList.push(.journal)
        updateCanGoBackForward()
        journalNoteToFocus = note
        return true
    }

    func navigateToPage(_ page: WindowPage) {
        EventsTracker.logBreadcrumb(message: "\(#function) \(page)", category: "BeamState")
        mode = .page

        currentNote = nil
        stopFocusOmnibox()
        currentPage = page
        backForwardList.push(.page(page))
        updateCanGoBackForward()
    }

    func navigateCurrentTab(toURL url: URL) {
        EventsTracker.logBreadcrumb(message: "\(#function) toURL \(url)", category: "BeamState")
        currentTab?.willSwitchToNewUrl(url: url)
        currentTab?.load(url: url)

        guard let currentTabId = currentTab?.id else { return }
        browserTabsManager.removeFromTabGroup(tabId: currentTabId)
        browserTabsManager.createNewGroup(for: currentTabId)
    }

    func addNewTab(origin: BrowsingTreeOrigin?, setCurrent: Bool = true, note: BeamNote? = nil, element: BeamElement? = nil, url: URL? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: origin)) \(String(describing: note)) \(String(describing: url))", category: "BeamState")
        let tab = BrowserTab(state: self, browsingTreeOrigin: origin, originMode: mode, note: note, rootElement: element, webView: webView)
        browserTabsManager.addNewTabAndGroup(tab, setCurrent: setCurrent, withURL: url)
        mode = .web
        return tab
    }

    /// Create a new browsertab in the current beam window. Will always switch the view mode to `.web`.
    /// - Parameters:
    ///   - url: the URL to open.
    ///   - originalQuery: optional search query to configure the browsing tree with.
    ///   - setCurrent: optional flag to set created tab as the new focused tab. Defaults to true.
    ///   - note: optional BeamNote to set as destination.
    ///   - rootElement: optional root BeamElement where collected content with be added to.
    ///   - webView: optional webview to create a new tab with
    /// - Returns: Returns the newly created tab. The returned tab can safely be discarded.
    @discardableResult func createTab(withURL url: URL, originalQuery: String? = nil, setCurrent: Bool = true, note: BeamNote? = nil, rootElement: BeamElement? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: note)) \(String(describing: url))", category: "BeamState")
        let origin = BrowsingTreeOrigin.searchBar(query: originalQuery ?? "<???>", referringRootId: browserTabsManager.currentTab?.browsingTree.rootId)
        let tab = addNewTab(origin: origin, setCurrent: setCurrent, note: note, element: rootElement, url: url, webView: webView)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self, weak tab] in
            guard self?.omniboxInfo.isFocused == false, let tab = tab else { return }
            tab.webviewWindow?.makeFirstResponder(tab.webView)
        }
        return tab
    }

    func createTabFromNote(_ note: BeamNote, element: BeamElement, withURL url: URL) {
        EventsTracker.logBreadcrumb(message: "createTabFromNote \(note.id)/\(note.title) element \(element.id)/\(element.kind) withURL \(url)", category: "BeamState")
        let origin = BrowsingTreeOrigin.linkFromNote(noteName: note.title)
        _ = addNewTab(origin: origin, note: note, element: element, url: url)
    }

    func createEmptyTab() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        _ = addNewTab(origin: nil)
    }

    func startNewSearchWithCurrentDestinationCard() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        keepDestinationNote = true
        startNewSearch()
    }

    func createTabFromNode(_ node: TextNode, withURL url: URL) {
        EventsTracker.logBreadcrumb(message: "createTabFromNode \(node) withURL \(url)", category: "BeamState")
        guard let note = node.root?.note else { return }
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: node.strippedText)
        _ = addNewTab(origin: origin, note: note, element: node.element, url: url)
    }

    func duplicate(tab: BrowserTab) {
        let duplicatedTab = BrowserTab(state: self, browsingTreeOrigin: tab.browsingTreeOrigin, originMode: .web, note: nil)
        browserTabsManager.addNewTabAndGroup(duplicatedTab, setCurrent: true, withURL: tab.url)
    }

    func closedTab(_ index: Int, allowClosingPinned: Bool = false) {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        let tab = self.browserTabsManager.tabs[index]
        closeTabIfPossible(tab, allowClosingPinned: allowClosingPinned)
    }

    /// returns true if the tab was closed
    func closeCurrentTab(allowClosingPinned: Bool = false) -> Bool {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        guard let currentTab = self.browserTabsManager.currentTab else { return false }
        return closeTabIfPossible(currentTab, allowClosingPinned: allowClosingPinned)
    }

    func closeAllTabs(exceptedTabAt index: Int? = nil, closePinnedTabs: Bool = false) {
        var tabIdToKeep: UUID?
        if let index = index {
            tabIdToKeep = browserTabsManager.tabs[index].id
        }
        cmdManager.beginGroup(with: "CloseAllTabs")
        for tab in browserTabsManager.tabs where tab.id != tabIdToKeep && (closePinnedTabs || !tab.isPinned) {
            guard let tabIndex = browserTabsManager.tabs.firstIndex(of: tab) else { continue }
            cmdManager.run(command: CloseTab(tab: tab, tabIndex: tabIndex, wasCurrentTab: browserTabsManager.currentTab === tab), on: self)
        }
        cmdManager.endGroup(forceGroup: true)
    }

    func closeTabsToTheRight(of tabIndex: Int) {
        guard tabIndex < browserTabsManager.tabs.count - 1 else { return }
        var rightTabs = [BrowserTab]()
        for rightTabIndex in tabIndex + 1...browserTabsManager.tabs.count - 1 {
            guard rightTabIndex > tabIndex, !browserTabsManager.tabs[rightTabIndex].isPinned else { continue }
            rightTabs.append(browserTabsManager.tabs[rightTabIndex])
        }

        cmdManager.beginGroup(with: "CloseTabsToTheRightCmdGrp")
        for tab in rightTabs {
            guard let tabIndex = browserTabsManager.tabs.firstIndex(of: tab) else { continue }
            cmdManager.run(command: CloseTab(tab: tab, tabIndex: tabIndex, wasCurrentTab: false), on: self)
        }
        cmdManager.endGroup(forceGroup: true)
    }

    @discardableResult
    private func closeTabIfPossible(_ tab: BrowserTab, allowClosingPinned: Bool = false) -> Bool {
        if tab.isPinned && !allowClosingPinned {
            if let nextUnpinnedTabIndex = browserTabsManager.tabs.firstIndex(where: { !$0.isPinned }) {
                browserTabsManager.showTab(at: nextUnpinnedTabIndex)
                return true
            }
            return false
        }
        guard let tabIndex = browserTabsManager.tabs.firstIndex(of: tab) else { return false }
        return cmdManager.run(command: CloseTab(tab: tab, tabIndex: tabIndex, wasCurrentTab: browserTabsManager.currentTab === tab), on: self, needsToBeSaved: tab.url != nil)
    }

    func createNewUntitledNote() -> BeamNote {
        let title = BeamNote.availableTitle(withPrefix: loc("New Note"))
        return BeamNote.create(title: title)
    }

    func fetchOrCreateNoteForQuery(_ query: String) -> BeamNote {
        EventsTracker.logBreadcrumb(message: "fetchOrCreateNoteForQuery \(query)", category: "BeamState")
        if let n = BeamNote.fetch(title: query) {
            return n
        }

        let n = BeamNote.create(title: query)
        return n
    }

    func handleOpenUrl(_ url: URL, note: BeamNote?, element: BeamElement?) {
        if URL.browserSchemes.contains(url.scheme) {
            if let note = note, let element = element {
                createTabFromNote(note, element: element, withURL: url)
            } else {
                _ = createTab(withURL: url, originalQuery: nil)
            }
        } else if url.scheme != nil {
            NSWorkspace.shared.open(url)
        } else {
            // if this is an unknow string, for now we do nothing.
            // we could potentially trigger a web search, but it's not really expected.
        }
    }

    private func urlFor(query: String) -> URL? {
        guard let url = query.toEncodedURL else {
            return searchEngine.searchURL(forQuery: query)
        }
        return url.urlWithScheme
    }

    func startQuery(_ node: TextNode, animated: Bool) {
        EventsTracker.logBreadcrumb(message: "startQuery \(node)", category: "BeamState")
        let query = node.currentSelectionWithFullSentences()
        guard !query.isEmpty, let url = urlFor(query: query) else { return }
        self.createTabFromNode(node, withURL: url)
        self.mode = .web
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func selectAutocompleteResult(_ result: AutocompleteResult) {
        EventsTracker.logBreadcrumb(message: "\(#function) - \(result)", category: "BeamState")
        switch result.source {
        case .searchEngine:
            guard let url = searchEngine.searchURL(forQuery: result.text) else {
                Logger.shared.logError("Couldn't retrieve search URL from search engine description", category: .search)
                break
            }

            if mode == .web && currentTab != nil && omniboxInfo.wasFocusedFromTab && currentTab?.shouldNavigateInANewTab(url: url) != true {
                navigateCurrentTab(toURL: url)
            } else {
                _ = createTab(withURL: url, originalQuery: result.text)
                mode = .web
            }

        case .history, .url, .topDomain, .mnemonic:
            let urlWithScheme = result.url?.urlWithScheme
            guard let url = urlWithScheme ?? urlFor(query: result.text) else {
                Logger.shared.logError("autocomplete result without correct url \(result.text)", category: .search)
                return
            }

            if url == urlWithScheme,
               let mnemonic = result.completingText,
               url.hostname?.starts(with: mnemonic) ?? false {
                // Create a mnemonic shortcut
                _ = try? GRDBDatabase.shared.insertMnemonic(text: mnemonic, url: LinkStore.shared.getOrCreateIdFor(url: url.absoluteString, title: nil))
            }

            if  mode == .web && currentTab != nil && omniboxInfo.wasFocusedFromTab && currentTab?.shouldNavigateInANewTab(url: url) != true {
                navigateCurrentTab(toURL: url)
            } else {
                _ = createTab(withURL: url, originalQuery: result.text, note: keepDestinationNote ? BeamNote.fetch(title: destinationCardName) : nil)
            }
            mode = .web

        case .note(let noteId, _):
            navigateToNote(id: noteId ?? result.uuid)

        case .action:
            result.handler?(self)
        case .createNote:
            if let noteTitle = result.information {
                navigateToNote(fetchOrCreateNoteForQuery(noteTitle))
            } else {
                autocompleteManager.animateToMode(.noteCreation)
            }
        }
    }

    func startOmniboxQuery(selectingNewIndex: Int? = nil) {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        let queryString = autocompleteManager.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if let result = autocompleteManager.autocompleteResult(at: selectingNewIndex ?? autocompleteManager.autocompleteSelectedIndex) {
            selectAutocompleteResult(result)
            return
        }
        stopFocusOmnibox()

        guard let url: URL = urlFor(query: queryString) else {
            Logger.shared.logError("Couldn't build search url from: \(queryString)", category: .search)
            return
        }

        // Logger.shared.logDebug("Start query: \(url)")

        if mode == .web && currentTab != nil && omniboxInfo.wasFocusedFromTab && currentTab?.shouldNavigateInANewTab(url: url) != true {
            navigateCurrentTab(toURL: url)
        } else {
            _ = createTab(withURL: url, originalQuery: queryString, note: keepDestinationNote ? BeamNote.fetch(title: destinationCardName) : nil)
        }
        autocompleteManager.clearAutocompleteResults()
        mode = .web
    }

    override public init() {
        data = AppDelegate.main.data
        super.init()
        setup(data: data)

        data.downloadManager.downloadList.$downloads.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &scope)

        setDefaultDisplayMode()
        setupObservers()
    }

    enum CodingKeys: String, CodingKey {
        case currentNote
        case mode
        case tabs
        case currentTab
        case backForwardList
    }

    required public init(from decoder: Decoder) throws {
        data = AppDelegate.main.data
        super.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let currentNoteTitle = try? container.decode(String.self, forKey: .currentNote) {
            currentNote = BeamNote.fetch(title: currentNoteTitle)
        }
        backForwardList = try container.decode(NoteBackForwardList.self, forKey: .backForwardList)

        browserTabsManager.tabs = try container.decode([BrowserTab].self, forKey: .tabs)
        if let tabIndex = try? container.decode(Int.self, forKey: .currentTab), tabIndex < browserTabsManager.tabs.count {
            browserTabsManager.currentTab = browserTabsManager.tabs[tabIndex]
        }

        setup(data: data)
        mode = try container.decode(Mode.self, forKey: .mode)
        setupObservers()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let note = currentNote {
            try container.encode(note.title, forKey: .currentNote)
        }
        try container.encode(backForwardList, forKey: .backForwardList)
        try container.encode(mode, forKey: .mode)
        try container.encode(browserTabsManager.tabs, forKey: .tabs)
        if let tab = currentTab {
            try container.encode(browserTabsManager.tabs.firstIndex(of: tab), forKey: .currentTab)
        }
    }

    func setup(data: BeamData) {
        destinationCardName = data.todaysName
        backForwardList.push(.journal)

        DocumentManager.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                guard let self = self else { return }
                self.backForwardList.purgeDeletedNote(withId: id)
                self.updateCanGoBackForward()
            }.store(in: &scope)
    }

    func setup(webView: WKWebView) {
        data.setup(webView: webView)
        ContentBlockingManager.shared.configure(webView: webView)
    }

    func generateTabs(_ number: Int = 100) {
        for _ in 0..<number {
            _ = createTab(withURL: URL(string: "https://beamapp.co")!, originalQuery: "beamapp.co")
        }
    }

    // MARK: Omnibox handling
    struct OmniboxLayoutInformation {
        fileprivate(set) var isFocused: Bool = true
        fileprivate(set) var isShownInJournal = true
        fileprivate(set) var wasFocusedFromJournalTop = true
        var wasFocusedFromTab = false
        fileprivate(set)var wasFocusedDirectlyFromMode = AutocompleteManager.Mode.general
    }

    func startShowingOmniboxInJournal() {
        guard !omniboxInfo.isShownInJournal else { return }
        omniboxInfo.isShownInJournal = true
    }

    func stopShowingOmniboxInJournal() {
        guard omniboxInfo.isShownInJournal else { return }
        omniboxInfo.isShownInJournal = false
    }

    func startFocusOmnibox(fromTab: Bool = false, updateResults: Bool = true, autocompleteMode: AutocompleteManager.Mode = .general) {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        omniboxInfo.wasFocusedFromTab = fromTab && mode == .web
        omniboxInfo.wasFocusedFromJournalTop = mode == .today && omniboxInfo.isShownInJournal
        guard updateResults else {
            omniboxInfo.isFocused = true
            return
        }
        autocompleteManager.mode = autocompleteMode
        omniboxInfo.wasFocusedDirectlyFromMode = autocompleteMode
        var selectedRange: Range<Int>?
        if mode == .web {
            if fromTab, let url = browserTabsManager.currentTab?.url?.absoluteString {
                selectedRange = url.wholeRange
                autocompleteManager.setQuery(url, updateAutocompleteResults: false)
            } else if !autocompleteManager.searchQuery.isEmpty {
                autocompleteManager.resetQuery()
            }
        }
        autocompleteManager.prepareResultsForAppearance(for: autocompleteManager.searchQuery) { [unowned self] in
            self.omniboxInfo.isFocused = true
            if let selectedRange = selectedRange {
                self.autocompleteManager.searchQuerySelectedRange = selectedRange
            }
        }
    }

    func stopFocusOmnibox() {
        guard omniboxInfo.isFocused else { return }
        omniboxInfo.isFocused = false
        if omniboxInfo.isShownInJournal {
            autocompleteManager.resetQuery()
            autocompleteManager.clearAutocompleteResults()
        }
    }

    func startNewSearch() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        if omniboxInfo.isFocused && (!omniboxInfo.isShownInJournal || !autocompleteManager.autocompleteResults.isEmpty) {
            // disabling shake from users feedback - https://linear.app/beamapp/issue/BE-2546/cmd-t-on-already-summoned-omnibox-makes-it-bounce
            // autocompleteManager.shakeOmniBox()
            stopFocusOmnibox()
            if omniboxInfo.isShownInJournal {
                autocompleteManager.clearAutocompleteResults()
            }
        } else {
            startFocusOmnibox(fromTab: false)
        }
    }

    func startNewNote() {
        startFocusOmnibox(fromTab: false, autocompleteMode: .noteCreation)
    }

    func resetDestinationCard() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        destinationCardName = currentTab?.noteController.noteOrDefault.title ?? data.todaysName
        destinationCardNameSelectedRange = nil
        destinationCardIsFocused = false
    }

    var cancellables = Set<AnyCancellable>()
    private func setupObservers() {
        DocumentManager.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                guard let self = self else { return }
                if self.currentNote?.id == id {
                    self.currentNote = nil
                    if self.mode == .note {
                        self.navigateToJournal(note: nil)
                    }
                }
            }.store(in: &cancellables)
    }

}

// MARK: - Browser Tabs
extension BeamState: BrowserTabsManagerDelegate {

    // convenient vars
    var hasBrowserTabs: Bool {
        !browserTabsManager.tabs.isEmpty
    }
    var hasUnpinnedBrowserTabs: Bool {
        browserTabsManager.tabs.first(where: { !$0.isPinned }) != nil
    }
    private weak var currentTab: BrowserTab? {
        browserTabsManager.currentTab
    }

    func showNextTab() {
        browserTabsManager.showNextTab()
    }

    func showPreviousTab() {
        browserTabsManager.showPreviousTab()
    }

    // MARK: BrowserTabsManagerDelegate
    func areTabsVisible(for manager: BrowserTabsManager) -> Bool {
        mode == .web
    }

    func tabsManagerDidUpdateTabs(_ tabs: [BrowserTab]) {
        if tabs.isEmpty {
            if let note = currentNote {
                navigateToNote(note)
            } else {
                navigateToJournal(note: nil, clearNavigation: true)
            }
        }
    }
    func tabsManagerDidChangeCurrentTab(_ currentTab: BrowserTab?, previousTab: BrowserTab?) {
        webIndexingController.currentTabDidChange(currentTab, previousCurrentTab: previousTab)
        resetDestinationCard()
        stopFocusOmnibox()
    }

    func tabsManagerBrowsingHistoryChanged(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }

    private func setDefaultDisplayMode() {
        if PreferencesManager.showWebOnLaunchIfTabs {
            let openTabs = browserTabsManager.tabs
            if openTabs.count > 0 {
                mode = .web
            }
            return
        }
    }

    func displayWelcomeTour() {
        guard let onboardingURL = URL(string: EnvironmentVariables.webOnboardingURL) else { return }
        createTab(withURL: onboardingURL)
        Persistence.Authentication.hasSeenWelcomeTour = true
    }
}

// MARK: - Notes focused state
extension BeamState {

    func updateNoteFocusedState(note: BeamNote, focusedElement: UUID, cursorPosition: Int) {
        if note == currentNote {
            notesFocusedStates.currentFocusedState = NoteEditFocusedState(elementId: focusedElement, cursorPosition: cursorPosition)
        }
        notesFocusedStates.saveNoteFocusedState(noteId: note.id, focusedElement: focusedElement, cursorPosition: cursorPosition)
    }
}
