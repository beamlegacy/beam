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

@objc class BeamState: NSObject, ObservableObject, Codable {
    var data: BeamData
    public var searchEngine: SearchEngine = GoogleSearch()

    @Published var currentNote: BeamNote? {
        didSet {
            EventsTracker.logBreadcrumb(message: "currentNote changed to \(String(describing: currentNote))", category: "BeamState")
            if let note = currentNote {
                recentsManager.currentNoteChanged(note)
                observeNoteDeletion(note)
            }
            focusOmniBox = false
        }
    }

    private(set) lazy var recentsManager: RecentsManager = {
        RecentsManager(with: DocumentManager())
    }()
    private(set) lazy var autocompleteManager: AutocompleteManager = {
        AutocompleteManager(with: data, searchEngine: searchEngine)
    }()
    private(set) lazy var browserTabsManager: BrowserTabsManager = {
        let manager = BrowserTabsManager(with: data, state: self)
        manager.delegate = self
        return manager
    }()
    private(set) lazy var noteMediaPlayerManager: NoteMediaPlayerManager = {
        NoteMediaPlayerManager()
    }()

    @Published var backForwardList = NoteBackForwardList()
    @Published var notesFocusedStates = NoteEditFocusedStateStorage()
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var focusOmniBox: Bool = true
    var useOmniboxV2 = false

    @Published var destinationCardIsFocused: Bool = false
    @Published var destinationCardName: String = ""
    @Published var destinationCardNameSelectedRange: Range<Int>?

    @Published var windowIsResizing = false
    @Published var windowIsMain = true
    @Published var windowFrame = CGRect.zero
    var associatedWindow: NSWindow? {
        AppDelegate.main.windows.first { $0.state === self }
    }

    @Published var mode: Mode = .today {
        didSet {
            EventsTracker.logBreadcrumb(message: "mode changed to \(mode)", category: "BeamState")
            browserTabsManager.updateTabsForStateModeChange(mode, previousMode: oldValue)
            updateCanGoBackForward()
            focusOmniBox = false

            if let leavingNote = currentNote, leavingNote.publicationStatus.isPublic, leavingNote.shouldUpdatePublishedVersion {
                BeamNoteSharingUtils.makeNotePublic(leavingNote, becomePublic: true)
            }
        }
    }

    @Published var currentPage: WindowPage?
    @Published var overlayViewModel: OverlayViewCenterViewModel = OverlayViewCenterViewModel()
    weak var currentEditor: BeamTextEdit?
    var editorShouldAllowMouseEvents: Bool {
        overlayViewModel.modalView == nil
    }
    var isShowingOnboarding: Bool {
        data.onboardingManager.needsToDisplayOnboard
    }

    var downloadButtonPosition: CGPoint?
    weak var downloaderWindow: PopoverWindow?

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
            if currentTab?.originMode == .today, let note = noteController?.note, note.type.isJournal {
                navigateToJournal(note: note)
            } else if let note = noteController?.note ?? currentNote {
                navigateToNote(note)
            } else {
                navigateToJournal(note: nil)
            }
        case .today, .note, .page:
            if hasBrowserTabs { mode = .web }
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

    @available(*, deprecated, message: "Using title might navigate to a different card if multiple databases, use ID if possible.")
    @discardableResult func navigateToNote(named: String, elementId: UUID? = nil) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) named \(named) - elementId \(String(describing: elementId))", category: "BeamState")
        //Logger.shared.logDebug("load note named \(named)")
        let note = BeamNote.fetchOrCreate(title: named)
        return navigateToNote(note, elementId: elementId)
    }

    @discardableResult func navigateToNote(id: UUID, elementId: UUID? = nil, unfold: Bool = false) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) id \(id) - elementId \(String(describing: elementId))", category: "BeamState")
        //Logger.shared.logDebug("load note named \(named)")
        guard let note = BeamNote.fetch(id: id) else {
            return false
        }
        return navigateToNote(note, elementId: elementId, unfold: unfold)
    }

    @discardableResult func navigateToNote(_ note: BeamNote, elementId: UUID? = nil, unfold: Bool = false) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) \(note) - elementId \(String(describing: elementId))", category: "BeamState")
        mode = .note

        guard note != currentNote else { return true }

        note.sources.refreshScores()
        data.noteFrecencyScorer.update(id: note.id, value: 1.0, eventType: .noteVisit, date: BeamDate.now, paramKey: .note30d0)
        data.noteFrecencyScorer.update(id: note.id, value: 1.0, eventType: .noteVisit, date: BeamDate.now, paramKey: .note30d1)
        currentPage = nil
        currentNote = note
        if let elementId = elementId {
            notesFocusedStates.currentFocusedState = NoteEditFocusedState(elementId: elementId, cursorPosition: 0, highlight: true, unfold: unfold)
        } else {
            notesFocusedStates.currentFocusedState = notesFocusedStates.getSavedNoteFocusedState(noteId: note.id)
        }

        autocompleteManager.resetQuery()
        autocompleteManager.autocompleteSelectedIndex = nil

        backForwardList.push(.note(note))
        updateCanGoBackForward()
        return true
    }

    @discardableResult func navigateToJournal(note: BeamNote?, clearNavigation: Bool = false) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: note))", category: "BeamState")
        mode = .today

        currentPage = nil
        currentNote = nil
        autocompleteManager.resetQuery()
        autocompleteManager.autocompleteSelectedIndex = nil

        if clearNavigation {
            backForwardList.clear()
        }
        backForwardList.push(.journal)
        updateCanGoBackForward()
        return true
    }

    func navigateToPage(_ page: WindowPage) {
        EventsTracker.logBreadcrumb(message: "\(#function) \(page)", category: "BeamState")
        mode = .page

        currentNote = nil
        autocompleteManager.resetQuery()
        autocompleteManager.autocompleteSelectedIndex = nil
        focusOmniBox = false
        currentPage = page
        backForwardList.push(.page(page))
        updateCanGoBackForward()
    }

    func navigateCurrentTab(toURL url: URL) {
        EventsTracker.logBreadcrumb(message: "\(#function) toURL \(url)", category: "BeamState")
        currentTab?.willSwitchToNewUrl(url: url)
        currentTab?.load(url: url)

        guard let currentTabId = currentTab?.id else { return }
        browserTabsManager.removeTabFromGroup(tabId: currentTabId)
        browserTabsManager.createNewGroup(for: currentTabId)
    }

    func addNewTab(origin: BrowsingTreeOrigin?, setCurrent: Bool = true, note: BeamNote? = nil, element: BeamElement? = nil, url: URL? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: origin)) \(String(describing: note)) \(String(describing: url))", category: "BeamState")
        let tab = BrowserTab(state: self, browsingTreeOrigin: origin, originMode: mode, note: note, rootElement: element, webView: webView)
        browserTabsManager.addNewTabAndGroup(tab, setCurrent: setCurrent, withURL: url)
        mode = .web
        return tab
    }

    func createTab(withURL url: URL, originalQuery: String?, setCurrent: Bool = true, note: BeamNote? = nil, rootElement: BeamElement? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: note)) \(String(describing: url))", category: "BeamState")
        let origin = BrowsingTreeOrigin.searchBar(query: originalQuery ?? "<???>")
        let tab = addNewTab(origin: origin, setCurrent: setCurrent, note: note, element: rootElement, url: url, webView: webView)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
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

    func createEmptyTabWithCurrentDestinationCard() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        guard let destinationNote = BeamNote.fetch(title: destinationCardName) else { return }
        _ = addNewTab(origin: nil, note: destinationNote)
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

    func closeAllTabsButCurrent() {
        cmdManager.beginGroup(with: "CloseAllTabsButCurrentCmdGrp")
        for tab in browserTabsManager.tabs where tab.id != browserTabsManager.currentTab?.id && !tab.isPinned {
            guard let tabIndex = browserTabsManager.tabs.firstIndex(of: tab) else { continue }
            cmdManager.run(command: CloseTab(tab: tab, tabIndex: tabIndex, wasCurrentTab: false), on: self)
        }
        cmdManager.endGroup(forceGroup: true)
    }

    func closeTabsToTheRight() {
        guard let currentTab = browserTabsManager.currentTab, let currentTabIndex = browserTabsManager.tabs.firstIndex(of: currentTab) else { return }
        var rightTabs = [BrowserTab]()
        for rightTabIndex in currentTabIndex + 1...browserTabsManager.tabs.count - 1 {
            guard rightTabIndex > currentTabIndex, !browserTabsManager.tabs[rightTabIndex].isPinned else { continue }
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

    func createNoteForQuery(_ query: String) -> BeamNote {
        EventsTracker.logBreadcrumb(message: "createNoteForQuery \(query)", category: "BeamState")
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
            searchEngine.query = query
            return URL(string: searchEngine.searchUrl)
        }
        return url.urlWithScheme
    }

    func startQuery(_ node: TextNode, animated: Bool) {
        EventsTracker.logBreadcrumb(message: "startQuery \(node)", category: "BeamState")
        let query = node.currentSelectionWithFullSentences()
        guard !query.isEmpty, let url = urlFor(query: query) else { return }

        let completeQuery = { [unowned self] in
            self.createTabFromNode(node, withURL: url)
            self.mode = .web
        }
        if animated {
            autocompleteManager.animateDirectQuery(with: query)
            let animationDuration = 300
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(animationDuration))) { [unowned self] in
                autocompleteManager.animateDirectQuery(with: nil)
                completeQuery()
            }
        } else {
            completeQuery()
        }
    }

    private func selectAutocompleteResult(_ result: AutocompleteResult) {
        EventsTracker.logBreadcrumb(message: "\(#function) - \(result)", category: "BeamState")
        switch result.source {
        case .autocomplete:
            searchEngine.query = result.text
            // Logger.shared.logDebug("Start search query: \(searchEngine.searchUrl)")
            let url = URL(string: searchEngine.searchUrl)!
            if mode == .web && currentTab != nil && currentTab?.shouldNavigateInANewTab(url: url) != true {
                navigateCurrentTab(toURL: url)
            } else {
                _ = createTab(withURL: url, originalQuery: result.text)
                mode = .web
            }

        case .history, .url, .topDomain:
            guard let url = result.url?.urlWithScheme ?? urlFor(query: result.text) else {
                Logger.shared.logError("autocomplete result without correct url \(result.text)", category: .search)
                return
            }
            if  mode == .web && currentTab != nil && currentTab?.shouldNavigateInANewTab(url: url) != true {
                navigateCurrentTab(toURL: url)
            } else {
                _ = createTab(withURL: url, originalQuery: result.text)
            }
            mode = .web

        case .note(let noteId, _):
            navigateToNote(id: noteId ?? result.uuid)

        case .createCard:
            navigateToNote(createNoteForQuery(result.text))
        }
        autocompleteManager.cancelAutocomplete()
    }

    func startQuery() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        let queryString = autocompleteManager.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        focusOmniBox = false
        if let result = autocompleteManager.autocompleteResult(at: autocompleteManager.autocompleteSelectedIndex) {
            autocompleteManager.resetQuery()
            selectAutocompleteResult(result)
            return
        }

        guard let url: URL = urlFor(query: queryString) else {
            Logger.shared.logError("Couldn't build search url from: \(queryString)", category: .search)
            return
        }

        // Logger.shared.logDebug("Start query: \(url)")

        if mode == .web && currentTab != nil && currentTab?.shouldNavigateInANewTab(url: url) != true {
            navigateCurrentTab(toURL: url)
        } else {
            _ = createTab(withURL: url, originalQuery: queryString)
        }
        autocompleteManager.cancelAutocomplete()
        autocompleteManager.resetQuery()
        mode = .web
    }

    override public init() {
        data = AppDelegate.main.data
        useOmniboxV2 = PreferencesManager.omniboxV2IsOn
        super.init()
        setup(data: data)

        data.downloadManager.$downloads.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &scope)
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
        useOmniboxV2 = PreferencesManager.omniboxV2IsOn
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
    }

    func encode(to encoder: Encoder) throws {
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

    func setFocusOmnibox() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        if mode == .web {
            if let url = browserTabsManager.currentTab?.url?.absoluteString {
                autocompleteManager.resetQuery()
                autocompleteManager.searchQuerySelectedRange = url.wholeRange
                autocompleteManager.setQuery(url, updateAutocompleteResults: false)
            } else {
                autocompleteManager.resetQuery()
            }
        }
        focusOmniBox = true
    }

    func startNewSearch() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        if mode == .web {
            autocompleteManager.cancelAutocomplete()
            autocompleteManager.resetQuery()
            createEmptyTab()
        }
        if focusOmniBox {
            autocompleteManager.shakeOmniBox()
        }
        focusOmniBox = true
    }

    func resetDestinationCard() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        destinationCardName = currentTab?.noteController.noteOrDefault.title ?? data.todaysName
        destinationCardNameSelectedRange = nil
        destinationCardIsFocused = false
    }

    private var noteDeletionCancellable: AnyCancellable?
    func observeNoteDeletion(_ note: BeamNote) {
        noteDeletionCancellable = note.$deleted.sink { [weak self, weak note] deleted in
            guard deleted else { return }
            self?.noteDeletionCancellable = nil
            guard let note = note, self?.mode == .note, self?.currentNote == note else { return }
            self?.navigateToJournal(note: nil)

            UserAlert.showError(message: "The note '\(note.title)' has been deleted.",
                                informativeText: "Navigating back to the journal.")
        }
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
        let wasFocused = focusOmniBox
        browserTabsManager.showNextTab()
        if wasFocused { setFocusOmnibox() }
    }

    func showPreviousTab() {
        let wasFocused = focusOmniBox
        browserTabsManager.showPreviousTab()
        if wasFocused { setFocusOmnibox() }
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
    func tabsManagerDidChangeCurrentTab(_ currentTab: BrowserTab?) {
        resetDestinationCard()
        if areTabsVisible(for: browserTabsManager), let tab = currentTab, tab.url == nil {
            setFocusOmnibox()
        } else {
            focusOmniBox = false
        }
    }

    func tabsManagerBrowsingHistoryChanged(canGoBack: Bool, canGoForward: Bool) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
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
