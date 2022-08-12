//
//  BeamState.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import Combine
import WebKit
import SwiftSoup
import BeamCore
import Sentry

@objc public class BeamState: NSObject, ObservableObject, Codable, BeamDocumentSource {
    var data: BeamData

    @Published var allNotesSortDescriptor: NSSortDescriptor?
    @Published var allNotesListType: ListType = .allNotes
    @Published var showDailyNotes = true

    public static var sourceId: String { "\(Self.self)" }

    let isIncognito: Bool
    var incognitoCookiesManager: CookiesManager?

    /// This property will give you access to the CookieManager object the most appropriate for this state
    /// If in Incognito mode, we will have the incognito cookie manager, otherwise the global one
    /// For now, this incognito manager is not used
    var cookieManager: CookiesManager {
        if let manager = incognitoCookiesManager, isIncognito {
            return manager
        }
        return data.cookieManager
    }

    private let searchEngine: SearchEngineDescription = PreferredSearchEngine()

    var searchEngineName: String {
        return searchEngine.name
    }

    @Published var currentNote: BeamNote? {
        didSet {
            EventsTracker.logBreadcrumb(message: "currentNote changed to \(String(describing: currentNote))", category: "BeamState")
            if let note = currentNote {
                recentsManager.currentNoteChanged(note)
            }
            stopFocusOmnibox()
            updateCurrentNoteTitleSubscription()
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
        RecentsManager()
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

    private(set) lazy var webIndexingController: WebIndexingController? = {
        guard !isIncognito else { return nil }
        return WebIndexingController(clusteringManager: data.clusteringManager)
    }()

    @Published var backForwardList = NoteBackForwardList()
    @Published var notesFocusedStates = NoteEditFocusedStateStorage()
    /// Capability to go back or forward in history, whether it's for the webview or notes/pages
    @Published var canGoBackForward: (back: Bool, forward: Bool) = (false, false)
    /// In web mode, we sometimes want to display the back or forward arrow in disabled mode
    @Published var shouldForceShowBackForward: (back: Bool, forward: Bool) = (false, false)
    @Published var isFullScreen: Bool = false
    @Published var omniboxInfo = OmniboxLayoutInformation()

    @Published var showSidebar = false
    @Published var useSidebar: Bool = false

    @Published var destinationCardIsFocused = false
    @Published var destinationCardName: String = ""
    @Published var destinationCardNameSelectedRange: Range<Int>?
    var keepDestinationNote = false

    @Published var sideNote: BeamNote?

    var associatedWindow: NSWindow? {
        AppDelegate.main.windows.first { $0.state === self }
    }
    func associatedPanel(for note: BeamNote) -> NSPanel? {
        AppDelegate.main.panels[note]
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
                BeamNoteSharingUtils.makeNotePublic(leavingNote, becomePublic: true, publicationGroups: leavingNote.publicationStatus.publicationGroups)
            }

            updateWindowTitle()
            showSidebar = false
        }
    }

    var cachedJournalScrollView: NSScrollView?
    var cachedJournalStackView: JournalSimpleStackView?
    @Published var journalScrollOffset: CGFloat = 0
    var lastScrollOffset = [UUID: CGFloat]()

    @Published var currentPage: WindowPage? {
        didSet {
            updateWindowTitle()
        }
    }

    @Published var overlayViewModel: OverlayViewCenterViewModel = OverlayViewCenterViewModel()

    var shouldDisableLeadingGutterHover: Bool = false

    weak var currentEditor: BeamTextEdit?
    var editorShouldAllowMouseEvents: Bool {
        overlayViewModel.modalView == nil
    }
    var editorShouldAllowMouseHoverEvents: Bool {
        !omniboxInfo.isFocused && !showSidebar
    }
    var isShowingOnboarding: Bool {
        data.onboardingManager.needsToDisplayOnboard
    }

    var downloadButtonPosition: CGPoint?

    private var navigateBackFromShortcutsToWeb = false

    private var lastQuickSearchDate: Date = .init()

    private var scope = Set<AnyCancellable>()
    let cmdManager = CommandManager<BeamState>()

    func goBack(openingInNewTab: Bool = false) {
        guard canGoBackForward.back else { return }
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
            if openingInNewTab, let url = currentTab?.backForwardList.backItem?.url {
                createTab(withURLRequest: URLRequest(url: url), setCurrent: false)
            } else {
                currentTab?.goBack()
            }
        }

        updateCanGoBackForward()
    }

    func goForward(openingInNewTab: Bool = false) {
        guard canGoBackForward.forward else { return }
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
            if openingInNewTab, let url = currentTab?.backForwardList.forwardItem?.url {
                createTab(withURLRequest: URLRequest(url: url), setCurrent: false)
            } else {
                currentTab?.goForward()
            }
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
            canGoBackForward = (back: !backForwardList.backList.isEmpty, forward: !backForwardList.forwardList.isEmpty)
            shouldForceShowBackForward = (false, false)
        case .web:
            canGoBackForward = (back: currentTab?.canGoBack ?? false, forward: currentTab?.canGoForward ?? false)
            // we keep the back and forward visible until we leave the web mode
            let forceBack = shouldForceShowBackForward.back || canGoBackForward.back || browserTabsManager.tabs.first { $0.canGoBack } != nil
            let forceForward = shouldForceShowBackForward.forward || canGoBackForward.forward || browserTabsManager.tabs.first { $0.canGoForward } != nil
            shouldForceShowBackForward = (forceBack, forceForward)
        }
    }

    @discardableResult func openNoteInMiniEditor(id: UUID) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) id \(id))", category: "BeamState")
        guard let note = BeamNote.fetch(id: id), let window = associatedWindow as? BeamWindow else {
            return false
        }

        MiniEditorPanel.presentMiniEditor(from: window, with: note)
        stopFocusOmnibox()
        return true
    }

    @discardableResult func openNoteInSplitView(id: UUID) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) id \(id))", category: "BeamState")
        guard let note = BeamNote.fetch(id: id) else {
            return false
        }

        sideNote = note
        stopFocusOmnibox()
        return true
    }

    @discardableResult func openNoteInNewWindow(id: UUID) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) id \(id))", category: "BeamState")

        guard let window = AppDelegate.main.createWindow(frame: nil) else { return false }
        window.state.navigateToNote(id: id)
        window.makeMain()

        stopFocusOmnibox()
        return true
    }

    @available(*, deprecated, message: "Using title might navigate to a different note if multiple databases, use ID if possible.")
    @discardableResult func navigateToNote(named: String, elementId: UUID? = nil) -> Bool {
        EventsTracker.logBreadcrumb(message: "\(#function) named \(named) - elementId \(String(describing: elementId))", category: "BeamState")
        //Logger.shared.logDebug("load note named \(named)")
        guard let note = try? BeamNote.fetchOrCreate(self, title: named) else { return false }
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

        note.sources.refreshScores {}
        data.noteFrecencyScorer.update(id: note.id, value: 1.0, eventType: .noteVisit, date: BeamDate.now, paramKey: .note30d0)
        data.noteFrecencyScorer.update(id: note.id, value: 1.0, eventType: .noteVisit, date: BeamDate.now, paramKey: .note30d1)
        NoteScorer.shared.incrementVisitCount(noteId: note.id)
        note.recordScoreWordCount()
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

        if page.id == WindowPage.shortcutsWindowPage.id {
            navigateBackFromShortcutsToWeb = (mode == .web)
        }

        mode = .page

        currentNote = nil
        stopFocusOmnibox()
        currentPage = page
        backForwardList.push(.page(page))
        updateCanGoBackForward()
    }

    func navigateCurrentTab(toURLRequest request: URLRequest) {
        guard let currentTab = currentTab else {
            Logger.shared.logError("Unable to navigate current tab without any tab", category: .general); return
        }
        navigateTab(currentTab, toURLRequest: request)
    }

    func navigateTab(_ tab: BrowserTab, toURLRequest request: URLRequest) {
        EventsTracker.logBreadcrumb(message: "\(#function) toURLRequest \(request)", category: "BeamState")
        tab.willSwitchToNewUrl(url: request.url)
        tab.load(request: request)

        guard let currentTabId = currentTab?.id else { return }
        browserTabsManager.removeFromTabNeighborhood(tabId: currentTabId)
        browserTabsManager.createNewNeighborhood(for: currentTabId)
    }

    func navigateBackFromShortcuts() {
        if navigateBackFromShortcutsToWeb {
            mode = .web
        } else {
            navigateToJournal(note: nil)
        }
    }

    func addNewTab(origin: BrowsingTreeOrigin?, setCurrent: Bool = true, note: BeamNote? = nil, element: BeamElement? = nil, request: URLRequest? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: origin)) \(String(describing: note)) \(String(describing: request))", category: "BeamState")
        let tab = BrowserTab(state: self, browsingTreeOrigin: origin, originMode: mode, note: note, rootElement: element, webView: webView)
        browserTabsManager.addNewTabAndNeighborhood(tab, setCurrent: setCurrent, withURLRequest: request)
        if setCurrent {
            mode = .web
        } else if tab.contentView.window == nil {
            let size = associatedWindow?.contentView?.bounds.size ?? CGSize(width: 1000, height: 1000)
            tab.contentView.frame = .init(origin: .zero, size: size)
            tab.contentView.layoutSubtreeIfNeeded()
        }
        return tab
    }

    /// Create a new browsertab in the current beam window. Will always switch the view mode to `.web`.
    /// - Parameters:
    ///   - request: the URLRequest to open.
    ///   - originalQuery: optional search query to configure the browsing tree with.
    ///   - setCurrent: optional flag to set created tab as the new focused tab. Defaults to true.
    ///   - note: optional BeamNote to set as destination.
    ///   - rootElement: optional root BeamElement where collected content with be added to.
    ///   - webView: optional webview to create a new tab with
    /// - Returns: Returns the newly created tab. The returned tab can safely be discarded.
    @discardableResult func createTab(withURLRequest request: URLRequest, originalQuery: String? = nil, setCurrent: Bool = true, note: BeamNote? = nil, rootElement: BeamElement? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        EventsTracker.logBreadcrumb(message: "\(#function) \(String(describing: note)) \(String(describing: request.url))", category: "BeamState")
        let origin = BrowsingTreeOrigin.searchBar(query: originalQuery ?? "<???>", referringRootId: browserTabsManager.currentTab?.browsingTree.rootId)
        let tab = addNewTab(origin: origin, setCurrent: setCurrent, note: note, element: rootElement, request: request, webView: webView)

        if setCurrent {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self, weak tab] in
                guard self?.omniboxInfo.isFocused == false, self?.currentTab  == tab, let tab = tab else { return }
                tab.webviewWindow?.makeFirstResponder(tab.webView)
            }
        }
        return tab
    }

    func createTabFromNote(_ note: BeamNote, element: BeamElement, withURLRequest request: URLRequest, setCurrent: Bool = true) {
        EventsTracker.logBreadcrumb(message: "createTabFromNote \(note.id)/\(note.title) element \(element.id)/\(element.kind) withURLRequest \(request)", category: "BeamState")
        let origin = BrowsingTreeOrigin.linkFromNote(noteName: note.title)
        _ = addNewTab(origin: origin, setCurrent: setCurrent, note: note, element: element, request: request)
    }

    func createEmptyTab() -> BrowserTab {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        let tab = addNewTab(origin: nil)
        tab.title = loc("New Tab")
        return tab
    }

    func startNewSearchWithCurrentDestinationCard() {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        keepDestinationNote = true
        startNewSearch()
    }

    func performQuickSearch(with request: URLRequest) {
        let now: Date = .init()
        guard now.timeIntervalSince(lastQuickSearchDate) > 1 else { return } // very basic debouncing...
        createTab(withURLRequest: request)
        lastQuickSearchDate = now
    }

    func createTabFromNode(_ node: TextNode, withURL url: URL) {
        EventsTracker.logBreadcrumb(message: "createTabFromNode \(node) withURL \(url)", category: "BeamState")
        guard let note = node.root?.note else { return }
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: node.strippedText)
        _ = addNewTab(origin: origin, note: note, element: node.element, request: URLRequest(url: url))
    }

    func duplicate(tab: BrowserTab) {
        guard let url = tab.url ?? tab.preloadUrl else { return }

        let interactionState = tab.interactionState

        let duplicatedTab = BrowserTab(state: self,
                                       browsingTreeOrigin: tab.browsingTreeOrigin,
                                       originMode: .web,
                                       note: nil,
                                       interactionState: interactionState)

        let request: URLRequest? = (interactionState == nil) ? URLRequest(url: url) : nil

        browserTabsManager.addNewTabAndNeighborhood(duplicatedTab, setCurrent: true, withURLRequest: request)
    }

    func closeTab(_ index: Int, allowClosingPinned: Bool = false) {
        guard self.browserTabsManager.tabs.count - 1 >= index else { return }
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
        let tabs = browserTabsManager.tabs.filter { $0.id != tabIdToKeep && (closePinnedTabs || !$0.isPinned) }
        closeTabs(tabs, groupName: "CloseAllTabs")
    }

    func closeTabsToTheRight(of tabIndex: Int) {
        guard tabIndex < browserTabsManager.tabs.count - 1 else { return }
        var rightTabs = [BrowserTab]()
        for rightTabIndex in tabIndex + 1...browserTabsManager.tabs.count - 1 {
            guard rightTabIndex > tabIndex, !browserTabsManager.tabs[rightTabIndex].isPinned else { continue }
            rightTabs.append(browserTabsManager.tabs[rightTabIndex])
        }
        closeTabs(rightTabs, groupName: "CloseTabsToTheRightCmdGrp")
    }

    func closeTabs(_ tabs: [BrowserTab], groupName: String = "CloseMultipleTabs") {
        cmdManager.beginGroup(with: groupName)
        for tab in tabs {
            guard let tabIndex = browserTabsManager.tabs.firstIndex(of: tab) else { continue }
            let cmd = CloseTab(tab: tab, tabIndex: tabIndex, wasCurrentTab: browserTabsManager.currentTab === tab,
                               group: browserTabsManager.group(for: tab))
            cmdManager.run(command: cmd, on: self)
        }
        cmdManager.endGroup(forceGroup: true)
    }

    @discardableResult
    private func closeTabIfPossible(_ tab: BrowserTab, allowClosingPinned: Bool = false) -> Bool {
        if tab.isPinned && !allowClosingPinned {
            if let nextUnpinnedTabIndex = browserTabsManager.tabs.firstIndex(where: { !$0.isPinned }) {
                browserTabsManager.setCurrentTab(at: nextUnpinnedTabIndex)
                return true
            }
            return false
        }
        guard let tabIndex = browserTabsManager.tabs.firstIndex(of: tab) else { return false }
        let cmd = CloseTab(tab: tab, tabIndex: tabIndex, wasCurrentTab: browserTabsManager.currentTab === tab,
                           group: browserTabsManager.group(for: tab))
        return cmdManager.run(command: cmd, on: self, needsToBeSaved: tab.url != nil)
    }

    /// Reloads all tabs which have a `.network` error
    @MainActor
    func reloadOfflineTabs() {
        for tab in browserTabsManager.tabs where tab.errorPageManager?.error == .network {
            tab.reload()
        }
    }

    enum TabOpeningOption {
        case inBackground, newWindow
    }

    func openTabGroup(_ group: TabGroup, openingOption: Set<TabOpeningOption> = []) {
        let links = LinkStore.shared.getLinks(for: group.pageIds)
        let urls = group.pageIds.compactMap({ URL(string: links[$0]?.url ?? "") })

        let state: BeamState
        if openingOption.contains(.newWindow), let window = AppDelegate.main.createWindow(frame: nil) {
            state = window.state
        } else {
            state = self
        }

        let inBackground = openingOption.contains(.inBackground)

        let tabs: [BrowserTab] = urls.compactMap { url in
            if let tab = state.browserTabsManager.openedTab(for: url) { return tab }
            return state.createTab(withURLRequest: URLRequest(url: url), setCurrent: !inBackground)
        }

        state.browserTabsManager.reopenGroup(group, withTabs: tabs)

        if mode != .web && hasBrowserTabs && !inBackground {
            mode = .web
        }
        stopFocusOmnibox()
    }

    func fetchOrCreateNoteForQuery(_ query: String) throws -> BeamNote {
        EventsTracker.logBreadcrumb(message: "fetchOrCreateNoteForQuery \(query)", category: "BeamState")
        return try BeamNote.fetchOrCreate(self, title: query)
    }

    func handleOpenUrl(_ url: URL, note: BeamNote?, element: BeamElement?, inBackground: Bool) {
        if URL.browserSchemes.contains(url.scheme) {
            if let note = note, let element = element {
                createTabFromNote(note, element: element, withURLRequest: URLRequest(url: url), setCurrent: !inBackground)
            } else {
                _ = createTab(withURLRequest: URLRequest(url: url), originalQuery: nil, setCurrent: !inBackground)
            }
            if inBackground, let currentEvent = NSApp.currentEvent, let window = associatedWindow {
                var location = currentEvent.locationInWindow.flippedPointToTopLeftOrigin(in: window)
                location.y -= 20
                overlayViewModel.presentTooltip(text: loc("Opened in background"), at: location)
            }
        } else if url.scheme != nil {
            NSWorkspace.shared.open(url)
        } else {
            // if this is an unknow string, for now we do nothing.
            // we could potentially trigger a web search, but it's not really expected.
        }
    }

    func urlFor(query: String) -> (URL?, Bool) {
        guard let url = query.toEncodedURL else {
            return (searchEngine.searchURL(forQuery: query), true)
        }
        return (url.urlWithScheme, false)
    }

    func startQuery(_ node: TextNode, animated: Bool) {
        EventsTracker.logBreadcrumb(message: "startQuery \(node)", category: "BeamState")
        // if no links create link from search query
        if node.element.outLinks.isEmpty {
            let query = node.currentSelectionWithFullSentences()
            let (url, _) = urlFor(query: query.trimmingCharacters(in: .whitespaces))
            guard !query.isEmpty, let url = url else { return }
            self.createTabFromNode(node, withURL: url)
            self.mode = .web
            return
        }

        // if link at cursor open tab with link
        if let url = node.linkAt(index: node.cursorPosition) {
            self.createTabFromNode(node, withURL: url)
            self.mode = .web
            return
        }

        // if link in element open tab with link closest to the end
        if let link = node.element.outLinks.first,
                  let url = URL(string: link) {
            self.createTabFromNode(node, withURL: url)
            self.mode = .web
            return
        }
    }

    private func selectAutocompleteResult(_ result: AutocompleteResult, modifierFlags: NSEvent.ModifierFlags? = nil) {
        EventsTracker.logBreadcrumb(message: "\(#function) - \(result)", category: "BeamState")
        switch result.source {
        case .searchEngine:
            guard let url = searchEngine.searchURL(forQuery: result.text) else {
                Logger.shared.logError("Couldn't retrieve search URL from search engine description", category: .search)
                break
            }

            if mode == .web && currentTab != nil && omniboxInfo.wasFocusedFromTab && currentTab?.shouldNavigateInANewTab(url: url) != true {
                navigateCurrentTab(toURLRequest: URLRequest(url: url))
                stopFocusOmnibox()
            } else {
                _ = createTab(withURLRequest: URLRequest(url: url), originalQuery: result.text)
                mode = .web
            }

        case .history, .url, .topDomain, .mnemonic:
            let urlWithScheme = result.url?.urlWithScheme
            let (urlFromText, _) = urlFor(query: result.text)
            guard let url = urlWithScheme ?? urlFromText else {
                Logger.shared.logError("autocomplete result without correct url \(result.text)", category: .search)
                return
            }

            if !isIncognito,
               url == urlWithScheme,
               let mnemonic = result.completingText,
               url.hostname?.starts(with: mnemonic) ?? false {
                // Create a mnemonic shortcut
                try? BeamData.shared.mnemonicManager?.insertMnemonic(text: mnemonic, url: LinkStore.shared.getOrCreateId(for: url.absoluteString, title: nil))
            }

            if  mode == .web && currentTab != nil && omniboxInfo.wasFocusedFromTab && currentTab?.shouldNavigateInANewTab(url: url) != true {
                navigateCurrentTab(toURLRequest: URLRequest(url: url))
                stopFocusOmnibox()
            } else {
                _ = createTab(withURLRequest: URLRequest(url: url), originalQuery: result.text, note: keepDestinationNote ? BeamNote.fetch(title: destinationCardName) : nil)
                mode = .web
            }

        case .note(let noteId, _):
            let noteId = noteId ?? result.uuid
            if let flags = modifierFlags, flags.contains(.shift) {
                openNoteInNewWindow(id: noteId)
            } else if let flags = modifierFlags, flags.contains(.command) {
                openNoteInSplitView(id: noteId)
            } else {
                navigateToNote(id: noteId)
            }
        case .action, .tabGroup:
            result.handler?(self)
        case .createNote:
            if let noteTitle = result.information {
                _ = try? navigateToNote(fetchOrCreateNoteForQuery(noteTitle))
            } else {
                autocompleteManager.animateToMode(.noteCreation)
            }
        }
    }

    func startOmniboxQuery(selectingNewIndex: Int? = nil, navigate: Bool = true, modifierFlags: NSEvent.ModifierFlags? = nil) {
        EventsTracker.logBreadcrumb(message: #function, category: "BeamState")
        let queryString = autocompleteManager.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        let index = selectingNewIndex ?? autocompleteManager.autocompleteSelectedIndex
        if let result = autocompleteManager.autocompleteResult(at: index) {
            autocompleteManager.recordItemSelection(index: index, source: result.source)
            selectAutocompleteResult(result, modifierFlags: modifierFlags)
            return
        }
        stopFocusOmnibox(sendAnalyticsEvent: false)

        let (url, isSearchUrl) = urlFor(query: queryString)
        guard let url: URL = url else {
            Logger.shared.logError("Couldn't build search url from: \(queryString)", category: .search)
            return
        }

        autocompleteManager.recordNoSelection(isSearch: isSearchUrl)
        sendOmniboxAnalyticsEvent()
        // Logger.shared.logDebug("Start query: \(url)")

        if !navigate { return }
        if mode == .web && currentTab != nil && omniboxInfo.wasFocusedFromTab && currentTab?.shouldNavigateInANewTab(url: url) != true {
            navigateCurrentTab(toURLRequest: URLRequest(url: url))
        } else {
            _ = createTab(withURLRequest: URLRequest(url: url), originalQuery: queryString, note: keepDestinationNote ? BeamNote.fetch(title: destinationCardName) : nil)
        }
        autocompleteManager.clearAutocompleteResults()
        mode = .web
    }

    public init(incognito: Bool = false) {
        data = BeamData.shared
        isIncognito = incognito
        if isIncognito {
            incognitoCookiesManager = CookiesManager()
        }
        super.init()
        setup(data: data)

        backForwardList.push(.journal)

        data.downloadManager.downloadList.$downloads.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &scope)

        setDefaultDisplayMode()
        setupObservers()
    }

    enum CodingKeys: String, CodingKey {
        case currentNote
        case currentPage
        case mode
        case tabs
        case currentTab
        case tabGroups
        case tabGroupIDs
        case backForwardList
        case allNotesMode
        case allNotesSortDescriptor
        case showDailyNotes
    }

    required public init(from decoder: Decoder) throws {
        data = BeamData.shared
        isIncognito = false
        super.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let descriptor = try? container.decode(SortDescriptor.self, forKey: .allNotesSortDescriptor) {
            let sortSelector: Selector? = descriptor.caseInsensitiveCompare ? #selector(NSString.caseInsensitiveCompare) : nil
            let sortDescriptor = NSSortDescriptor(key: descriptor.key,
                                                  ascending: descriptor.ascending,
                                                  selector: sortSelector)
            allNotesSortDescriptor = sortDescriptor
        }
        if let mode = try? container.decode(ListType.self, forKey: .allNotesMode) {
            allNotesListType = mode
        }
        if let showJournal = try? container.decode(Bool.self, forKey: .showDailyNotes) {
            showDailyNotes = showJournal
        }

        if let currentNoteTitle = try? container.decode(String.self, forKey: .currentNote) {
            currentNote = BeamNote.fetch(title: currentNoteTitle)
        }
        if let page = try? container.decode(String.self, forKey: .currentPage) {
            if let pageID = WindowPageID(rawValue: page) {
                currentPage = WindowPage.page(for: pageID)
            }
        }
        backForwardList = try container.decode(NoteBackForwardList.self, forKey: .backForwardList)

        let decodedTabs = try container.decode([BrowserTab].self, forKey: .tabs).filter { !$0.isPinned }
        browserTabsManager.tabs.append(contentsOf: decodedTabs)
        if let currentTabId = try? container.decode(UUID.self, forKey: .currentTab),
           let tab = browserTabsManager.tabs.first(where: { $0.id == currentTabId }) {
            browserTabsManager.setCurrentTab(tab)
        } else if let tabIndex = try? container.decode(Int.self, forKey: .currentTab),
                  tabIndex < browserTabsManager.tabs.count {
            browserTabsManager.setCurrentTab(at: tabIndex)
        }

        let tabGroups = try container.decode([TabGroup].self, forKey: .tabGroups)
        let tabGroupIDs = try container.decode([BrowserTab.ID: TabGroup.ID].self, forKey: .tabGroupIDs)

        for tab in browserTabsManager.tabs {
            if let groupID = tabGroupIDs[tab.id],
               let group = tabGroups.first(where: { $0.id == groupID }) {
                browserTabsManager.moveTabToGroup(tab.id, group: group)
            }
        }
        
        for group in tabGroups {
            if group.collapsed {
                browserTabsManager.groupTabsInGroup(group)
            }
        }

        setup(data: data)

        if PreferencesManager.defaultWindowMode == .webTabs && hasBrowserTabs {
            mode = .web
        } else {
            mode = try container.decode(Mode.self, forKey: .mode)
        }

        setupObservers()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let sortDescriptor = allNotesSortDescriptor, let key = sortDescriptor.key {
            let descriptor = SortDescriptor(key: key,
                                            ascending: sortDescriptor.ascending,
                                            caseInsensitiveCompare: sortDescriptor.selector == #selector(NSString.caseInsensitiveCompare))
            try container.encode(descriptor, forKey: .allNotesSortDescriptor)
        }
        try container.encode(allNotesListType, forKey: .allNotesMode)
        try container.encode(showDailyNotes, forKey: .showDailyNotes)

        if let note = currentNote {
            try container.encode(note.title, forKey: .currentNote)
        }
        if let page = currentPage {
            try container.encode(page.id.rawValue, forKey: .currentPage)
        }
        try container.encode(backForwardList, forKey: .backForwardList)
        try container.encode(mode, forKey: .mode)
        try container.encode(browserTabsManager.tabs.filter({ !$0.isPinned }), forKey: .tabs)
        if let tab = currentTab {
            try container.encode(tab.id, forKey: .currentTab)
        }

        var tabGroups: Set<TabGroup> = []
        var tabGroupIDs: [BrowserTab.ID: TabGroup.ID] = [:]

        for tab in browserTabsManager.tabs {
            if let group = browserTabsManager.group(for: tab) {
                tabGroups.insert(group)
                tabGroupIDs[tab.id] = group.id
            }
        }

        try container.encode(Array(tabGroups), forKey: .tabGroups)
        try container.encode(tabGroupIDs, forKey: .tabGroupIDs)
    }

    func setup(data: BeamData) {
        destinationCardName = data.todaysName

        BeamDocumentCollection.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] deletedDocument in
                guard let self = self else { return }
                self.backForwardList.purgeDeletedNote(withId: deletedDocument.id)
                self.updateCanGoBackForward()
            }.store(in: &scope)
    }

    func setup(webView: WKWebView) {
        if isIncognito, let cookiesManager = incognitoCookiesManager {
            cookiesManager.setupCookies(for: webView)
        } else {
            data.cookieManager.setupCookies(for: webView)
        }
        ContentBlockingManager.shared.configure(webView: webView)
    }

    func generateTabs(_ number: Int = 100) {
        for _ in 0..<number {
            _ = createTab(withURLRequest: URLRequest(url: URL(string: "https://beamapp.co")!), originalQuery: "beamapp.co")
        }
    }

    func updateWindowTitle() {
        switch mode {
        case .today:
            associatedWindow?.title = "Journal"
        case .page:
            associatedWindow?.title = currentPage?.title ?? "Beam"
        case .note:
            associatedWindow?.title = currentNote?.title ?? "Beam"
        case .web:
            associatedWindow?.title = currentTab?.title ?? "Beam"
        }
    }

    private var currentNoteTitleSubscription: AnyCancellable?

    private func updateCurrentNoteTitleSubscription() {
        currentNoteTitleSubscription = currentNote?.$title.sink { [weak self] title in
            self?.associatedWindow?.title = title
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
        autocompleteManager.resetAnalyticsEvent()
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

    private func sendOmniboxAnalyticsEvent() {
        if let event = autocompleteManager.analyticsEvent, !isIncognito {
            data.analyticsCollector.record(event: event)
            autocompleteManager.resetAnalyticsEvent()
        }
    }

    func stopFocusOmnibox(sendAnalyticsEvent: Bool = true) {
        guard omniboxInfo.isFocused else { return }
        if sendAnalyticsEvent { sendOmniboxAnalyticsEvent() }
        omniboxInfo.isFocused = false
        if omniboxInfo.isShownInJournal {
            autocompleteManager.resetQuery()
            autocompleteManager.clearAutocompleteResults()
        }
        if mode == .web, let currentTab = currentTab {
            currentTab.makeFirstResponder()
        }
    }

    func shouldAllowFirstResponderTakeOver(_ responder: NSResponder?) -> Bool {
        if omniboxInfo.isFocused, responder is BeamWebView {
            // So here we have the webview asking the become first responder, while the omnibox is still focused.
            // if the last event is a recent mouse down -> we allow it.
            // otherwise, it's most likely the website trying to auto focus a field -> we refuse it.
            // see more here: https://linear.app/beamapp/issue/BE-3557/page-loading-is-dismissing-omnibox
            if let currentEvent = NSApp.currentEvent, currentEvent.isLeftClick {
                let timeSinceEvent = ProcessInfo.processInfo.systemUptime - currentEvent.timestamp
                return timeSinceEvent < 0.1 // left click older than 100ms are not related.
            }
            return false
        }
        return true
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
            CustomPopoverPresenter.shared.dismissPopovers(animated: false)
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
        BeamDocumentCollection.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] deletedDocument in
                guard let self = self else { return }
                if self.currentNote?.id == deletedDocument.id {
                    self.currentNote = nil
                    if self.mode == .note {
                        self.navigateToJournal(note: nil)
                    }
                }
            }.store(in: &cancellables)

        PreferencesManager.$useSidebar.sink { [unowned self] value in
            useSidebar = value
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
        webIndexingController?.currentTabDidChange(currentTab, previousCurrentTab: previousTab)
        resetDestinationCard()
        stopFocusOmnibox()
    }

    func tabsManagerBrowsingHistoryChanged(canGoBack: Bool, canGoForward: Bool) {
        updateCanGoBackForward()
    }

    func tabsManagerCurrentTabDidChangeDisplayInformation(_ currentTab: BrowserTab?) {
        updateWindowTitle()
        (associatedWindow as? BeamWindow)?.touchBarController?.updateForBrowserTabChange()
    }

    private func setDefaultDisplayMode() {
        let destinationMode: Mode
        switch PreferencesManager.defaultWindowMode {
        case .webTabs where hasBrowserTabs:
            destinationMode = .web
        default:
            destinationMode = .today
        }
        if mode != destinationMode {
            mode = destinationMode
        }
    }

    func displayWelcomeTour() {
        guard let onboardingURL = URL(string: EnvironmentVariables.webOnboardingURL) else { return }
        createTab(withURLRequest: URLRequest(url: onboardingURL))
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

enum ListType: String, Codable {
    case allNotes
    case privateNotes
    case publicNotes
    case onProfileNotes
}

private struct SortDescriptor: Codable {
    let key: String
    let ascending: Bool
    let caseInsensitiveCompare: Bool
}
