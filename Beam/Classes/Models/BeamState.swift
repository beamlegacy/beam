//
//  BeamState.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//
// swiftlint:disable file_length

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
            }
            focusOmniBox = false
        }
    }
    @Published var scrollToElementId: UUID?

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
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var focusOmniBox: Bool = true

    @Published var destinationCardIsFocused: Bool = false
    @Published var destinationCardName: String = ""
    @Published var destinationCardNameSelectedRange: Range<Int>?
    var bidirectionalPopover: BidirectionalPopover?

    @Published var windowIsResizing = false

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
    func goBack() {
        guard canGoBack else { return }
        switch mode {
        // swiftlint:disable:next fallthrough no_fallthrough_only
        case .note, .page: fallthrough
        case .today:
            if let back = backForwardList.goBack() {
                switch back {
                case .journal:
                    mode = .today
                    currentNote = nil
                case let .note(note):
                    mode = .note
                    currentNote = note
                case let .page(page):
                    mode = .page
                    currentPage = page
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
        // swiftlint:disable:next fallthrough no_fallthrough_only
        case .note, .page: fallthrough
        case .today:
            if let forward = backForwardList.goForward() {
                switch forward {
                case .journal:
                    mode = .today
                    currentNote = nil
                case let .note(note):
                    mode = .note
                    currentNote = note
                case let .page(page):
                    mode = .page
                    currentPage = page
                }
            }
        case .web:
            currentTab?.goForward()
        }

        updateCanGoBackForward()
    }

    func toggleBetweenWebAndNote() {
        guard let note = currentTab?.noteController.note else { return }

        switch mode {
        case .web:
            if currentTab?.originMode == .today && note.type.isJournal {
                navigateToJournal(note: note)
            } else {
                navigateToNote(note)
            }
        case .today, .note, .page:
            if hasBrowserTabs { mode = .web }
        }
    }

    func updateCanGoBackForward() {
        switch mode {
        // swiftlint:disable:next fallthrough no_fallthrough_only
        case .today: fallthrough
        case .note, .page:
            canGoBack = !backForwardList.backList.isEmpty
            canGoForward = !backForwardList.forwardList.isEmpty
        case .web:
            canGoBack = currentTab?.canGoBack ?? false
            canGoForward = currentTab?.canGoForward ?? false
        }
    }

    @discardableResult func navigateToNote(named: String, elementId: UUID? = nil) -> Bool {
        //Logger.shared.logDebug("load note named \(named)")
        let note = BeamNote.fetchOrCreate(data.documentManager, title: named)
        return navigateToNote(note, elementId: elementId)
    }

    @discardableResult func navigateToNote(id: UUID, elementId: UUID? = nil) -> Bool {
        //Logger.shared.logDebug("load note named \(named)")
        guard let note = BeamNote.fetch(data.documentManager, id: id) else {
            return false
        }
        return navigateToNote(note, elementId: elementId)
    }

    @discardableResult func navigateToNote(_ note: BeamNote, elementId: UUID? = nil) -> Bool {
        mode = .note

        guard note != currentNote else { return true }

        note.sources.refreshScores()
        currentPage = nil
        currentNote = note
        scrollToElementId = elementId
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
        currentTab?.load(url: url)
    }

    func addNewTab(origin: BrowsingTreeOrigin?, setCurrent: Bool = true, note: BeamNote, element: BeamElement? = nil, url: URL? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        let tab = BrowserTab(state: self, browsingTreeOrigin: origin, originMode: mode, note: note, rootElement: element, webView: webView)
        browserTabsManager.addNewTab(tab, setCurrent: setCurrent, withURL: url)
        mode = .web
        return tab
    }

    func createTab(withURL url: URL, originalQuery: String?, setCurrent: Bool = true, note: BeamNote? = nil, rootElement: BeamElement? = nil, webView: BeamWebView? = nil) -> BrowserTab {
        let origin = BrowsingTreeOrigin.searchBar(query: originalQuery ?? "<???>")
        return addNewTab(origin: origin, setCurrent: setCurrent, note: note ?? data.todaysNote, element: rootElement, url: url, webView: webView)
    }

    func createTabFromNote(_ note: BeamNote, element: BeamElement, withURL url: URL) {
        let origin = BrowsingTreeOrigin.linkFromNote(noteName: note.title)
        _ = addNewTab(origin: origin, note: note, element: element, url: url)
    }

    func createEmptyTab() {
        _ = addNewTab(origin: nil, note: data.todaysNote)
    }

    func createTabFromNode(_ node: TextNode, withURL url: URL) {
        guard let note = node.root?.note else { return }
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: node.strippedText)
        _ = addNewTab(origin: origin, note: note, element: node.element, url: url)
    }

    func createNoteForQuery(_ query: String) -> BeamNote {
        if let n = BeamNote.fetch(data.documentManager, title: query) {
            return n
        }

        let n = BeamNote.create(data.documentManager, title: query)

        let e = BeamElement()
        e.text = BeamText(text: query, attributes: [.internalLink(n.id)])
        data.todaysNote.insert(e, after: data.todaysNote.children.last)
        try? GRDBDatabase.shared.append(note: data.todaysNote)

        return n
    }

    private func urlFor(query: String) -> URL? {
        //TODO make a better url detector and rewritter to transform xxx.com in https://xxx.com with less corner cases and clearer code path:
        let csCopy = CharacterSet(bitmapRepresentation: CharacterSet.urlPathAllowed.bitmapRepresentation)
        guard query.mayBeURL, let u = URL(string: query.addingPercentEncoding(withAllowedCharacters: csCopy) ?? query) else {
            searchEngine.query = query
            return URL(string: searchEngine.searchUrl)
        }
        return u.urlWithScheme
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
            if  mode == .web && currentTab != nil && currentTab?.url == nil {
                navigateCurrentTab(toURL: url)
            } else {
                _ = createTab(withURL: url, originalQuery: result.text)
            }
            mode = .web

        case .note:
            navigateToNote(named: result.text)

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
        destinationCardName = currentTab?.noteController.note.title ?? data.todaysName
        destinationCardNameSelectedRange = nil
        destinationCardIsFocused = false
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
