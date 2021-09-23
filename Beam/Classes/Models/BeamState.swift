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

@objc class BeamState: NSObject, ObservableObject, Codable {
    var data: BeamData
    public var searchEngine: SearchEngine = GoogleSearch()

    @Published var currentNote: BeamNote? {
        didSet {
            if let note = currentNote {
                recentsManager.currentNoteChanged(note)
                handleNoteDeletion(note)
            }
            focusOmniBox = false
        }
    }

    private(set) lazy var recentsManager: RecentsManager = {
        RecentsManager(with: data.documentManager)
    }()
    private(set) lazy var autocompleteManager: AutocompleteManager = {
        AutocompleteManager(with: data, searchEngine: searchEngine)
    }()
    private(set) lazy var browserTabsManager: BrowserTabsManager = {
        let manager = BrowserTabsManager(with: data)
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

    @Published var destinationCardIsFocused: Bool = false
    @Published var destinationCardName: String = ""
    @Published var destinationCardNameSelectedRange: Range<Int>?

    @Published var windowIsResizing = false
    @Published var windowFrame = CGRect.zero

    @Published var mode: Mode = .today {
        didSet {
            browserTabsManager.updateTabsForStateModeChange(mode, previousMode: oldValue)
            updateCanGoBackForward()
            focusOmniBox = false
        }
    }

    @Published var currentPage: WindowPage?
    @Published var overlayViewModel: OverlayViewCenterViewModel = OverlayViewCenterViewModel()

    var downloadButtonPosition: CGPoint?
    weak var downloaderWindow: AutoDismissingWindow?

    private var scope = Set<AnyCancellable>()
    let cmdManager = CommandManager<BeamState>()

    func goBack() {
        guard canGoBack else { return }
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
        //Logger.shared.logDebug("load note named \(named)")
        let note = BeamNote.fetchOrCreate(data.documentManager, title: named)
        return navigateToNote(note, elementId: elementId)
    }

    @discardableResult func navigateToNote(id: UUID, elementId: UUID? = nil, unfold: Bool = false) -> Bool {
        //Logger.shared.logDebug("load note named \(named)")
        guard let note = BeamNote.fetch(data.documentManager, id: id) else {
            return false
        }
        return navigateToNote(note, elementId: elementId, unfold: unfold)
    }

    @discardableResult func navigateToNote(_ note: BeamNote, elementId: UUID? = nil, unfold: Bool = false) -> Bool {
        mode = .note

        guard note != currentNote else { return true }

        note.sources.refreshScores()
        data.noteFrecencyScorer.update(id: note.id, value: 1.0, eventType: .noteVisit, date: BeamDate.now, paramKey: .note30d0)
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
        currentTab?.willSwitchToNewUrl(url: url)
        currentTab?.load(url: url)
    }

    func addNewTab(origin: BrowsingTreeOrigin?, setCurrent: Bool = true, note: BeamNote? = nil, element: BeamElement? = nil, url: URL? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        let tab = BrowserTab(state: self, browsingTreeOrigin: origin, originMode: mode, note: note, rootElement: element, webView: webView)
        browserTabsManager.addNewTab(tab, setCurrent: setCurrent, withURL: url)
        mode = .web
        return tab
    }

    func createTab(withURL url: URL, originalQuery: String?, setCurrent: Bool = true, note: BeamNote? = nil, rootElement: BeamElement? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        let origin = BrowsingTreeOrigin.searchBar(query: originalQuery ?? "<???>")
        return addNewTab(origin: origin, setCurrent: setCurrent, note: note, element: rootElement, url: url, webView: webView)
    }

    func createTabFromNote(_ note: BeamNote, element: BeamElement, withURL url: URL) {
        let origin = BrowsingTreeOrigin.linkFromNote(noteName: note.title)
        _ = addNewTab(origin: origin, note: note, element: element, url: url)
    }

    func createEmptyTab() {
        _ = addNewTab(origin: nil)
    }

    func createEmptyTabWithCurrentDestinationCard() {
        guard let destinationNote = BeamNote.fetch(data.documentManager, title: destinationCardName) else { return }
        _ = addNewTab(origin: nil, note: destinationNote)
    }

    func createTabFromNode(_ node: TextNode, withURL url: URL) {
        guard let note = node.root?.note else { return }
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: node.strippedText)
        _ = addNewTab(origin: origin, note: note, element: node.element, url: url)
    }

    func closedTab(_ index: Int) {
        let tab = self.browserTabsManager.tabs[index]
        cmdManager.run(command: CloseTab(tab: tab), on: self)
    }

    func closeCurrentTab() -> Bool {
        guard let currentTab = self.browserTabsManager.currentTab else { return false }
        return cmdManager.run(command: CloseTab(tab: currentTab), on: self)
    }

    func createNoteForQuery(_ query: String) -> BeamNote {
        if let n = BeamNote.fetch(data.documentManager, title: query) {
            return n
        }

        let n = BeamNote.create(data.documentManager, title: query)

        let e = BeamElement()
        e.text = BeamText(text: query, attributes: [.internalLink(n.id)])
        data.todaysNote.insert(e, after: data.todaysNote.children.last)

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
        switch result.source {
        case .autocomplete:
            searchEngine.query = result.text
            // Logger.shared.logDebug("Start search query: \(searchEngine.searchUrl)")
            let url = URL(string: searchEngine.searchUrl)!
            if mode == .web, currentTab != nil {
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
            if  mode == .web && currentTab != nil {
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
        let queryString = autocompleteManager.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        focusOmniBox = false
        if let index = autocompleteManager.autocompleteSelectedIndex {
            let result = autocompleteManager.autocompleteResults[index]
            autocompleteManager.resetQuery()
            selectAutocompleteResult(result)
            return
        }

        guard let url: URL = urlFor(query: queryString) else {
            Logger.shared.logError("Couldn't build search url from: \(queryString)", category: .search)
            return
        }

        // Logger.shared.logDebug("Start query: \(url)")

        if mode == .web, currentTab != nil {
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
        super.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let currentNoteTitle = try? container.decode(String.self, forKey: .currentNote) {
            currentNote = BeamNote.fetch(data.documentManager, title: currentNoteTitle)
        }
        backForwardList = try container.decode(NoteBackForwardList.self, forKey: .backForwardList)

        browserTabsManager.tabs = try container.decode([BrowserTab].self, forKey: .tabs)
        if let tabIndex = try? container.decode(Int.self, forKey: .currentTab), tabIndex < browserTabsManager.tabs.count {
            browserTabsManager.currentTab = browserTabsManager.tabs[tabIndex]
        }

        setup(data: data)
        mode = try container.decode(Mode.self, forKey: .mode)

        for tab in browserTabsManager.tabs {
            tab.postLoadSetup(state: self)
        }
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

    func focusOmnibox() {
        if let url = browserTabsManager.currentTab?.url?.absoluteString, mode == .web {
            autocompleteManager.searchQuerySelectedRange = url.wholeRange
            autocompleteManager.setQueryWithoutAutocompleting(url)
        }
        focusOmniBox = true
    }

    func startNewSearch() {
        autocompleteManager.cancelAutocomplete()
        autocompleteManager.resetQuery()
        if mode == .web {
            createEmptyTab()
        }
        if focusOmniBox {
            autocompleteManager.shakeOmniBox()
        }
        focusOmniBox = true
    }

    func resetDestinationCard() {
        destinationCardName = currentTab?.noteController.noteOrDefault.title ?? data.todaysName
        destinationCardNameSelectedRange = nil
        destinationCardIsFocused = false
    }

    private var noteDeletionCancellable: AnyCancellable?
    func handleNoteDeletion(_ note: BeamNote) {
        noteDeletionCancellable = note.$deleted.sink { [unowned self] deleted in
            guard deleted else { return }
            noteDeletionCancellable = nil
            self.navigateToJournal(note: nil)
            let alert = NSAlert()
            alert.messageText = "The note '\(note.title)' has been deleted."
            alert.alertStyle = .critical
            alert.informativeText = "Navigating back to the journal."
            alert.runModal()
        }
    }
}

// MARK: - Browser Tabs
extension BeamState: BrowserTabsManagerDelegate {

    // convenient vars
    var hasBrowserTabs: Bool {
        !browserTabsManager.tabs.isEmpty
    }
    private weak var currentTab: BrowserTab? {
        browserTabsManager.currentTab
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
        focusOmniBox = false
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

// MARK: - Search
extension BeamState {

    func search() {
        switch mode {
        case .today:
            break
        case .note:
            break
        case .web:
            browserTabsManager.currentTab?.searchInTab()
        case .page:
            break
        }
    }
}
