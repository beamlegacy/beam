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

let NoteDisplayThreshold = Float(0.0)
//swiftlint:disable:next type_body_length
@objc class BeamState: NSObject, ObservableObject, WKHTTPCookieStoreObserver, Codable {
    var data: BeamData
    public var searchEngine: SearchEngine = GoogleSearch()

    @Published var currentNote: BeamNote? {
        didSet {
            if let note = currentNote {
                recentsManager.currentNoteChanged(note)
            }
        }
    }
    private(set) lazy var recentsManager: RecentsManager = {
        return RecentsManager(with: data.documentManager)
    }()
    private(set) lazy var autocompleteManager: AutocompleteManager = {
        return AutocompleteManager(with: data)
    }()

    @Published var backForwardList = NoteBackForwardList()
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var focusOmniBox: Bool = true

    @Published var destinationCardIsFocused: Bool = false
    @Published var destinationCardName: String = ""
    @Published var destinationCardNameSelectedRange: [Range<Int>]?
    var bidirectionalPopover: BidirectionalPopover?

    @Published var windowIsResizing = false

    @Published var mode: Mode = .today {
        didSet {
            switch oldValue {
            // swiftlint:disable:next fallthrough no_fallthrough_only
            case .note, .page: fallthrough
            case .today:
                if mode == .web {
                    currentTab?.startReading()
                }

            case .web:
                switch mode {
                case .note:
                    currentTab?.switchToCard()
                case .today:
                    currentTab?.switchToNewSearch()
                default:
                    break
                }
            }
            updateCanGoBackForward()
        }
    }

    @Published public var tabs: [BrowserTab] = [] {
        didSet {
            for tab in tabs {
                tab.onNewTabCreated = { [weak self] newTab in
                    guard let self = self else { return }
                    self.tabs.append(newTab)
                    // if var note = self.currentNote {
                    // TODO bind visited sites with note contents:
                    //                        if note.searchQueries.contains(newTab.originalQuery) {
                    //                            if let url = newTab.url {
                    //                                note.visitedSearchResults.append(VisitedPage(originalSearchQuery: newTab.originalQuery, url: url, date: Date(), duration: 0))
                    //                                self.currentNote = note
                    //                            }
                    //                        }
                    //                    }
                }

                tab.appendToIndexer = { [weak self] url, read in
                    guard let self = self else { return }
                    guard let doc = try? SwiftSoup.parse(read.content, url.absoluteString) else { return }
                    let text: String = html2Text(url: url, doc: doc)
                    self.data.index.append(document: IndexDocument(source: url.absoluteString, title: read.title, contents: text))
                }
            }

            if tabs.isEmpty {
                if let note = currentNote {
                    navigateToNote(note)
                } else {
                    navigateToJournal()
                }
            }
        }
    }

    @Published var currentTab: BrowserTab? {
        didSet {
            if self.mode == .web {
                oldValue?.switchToOtherTab()
                currentTab?.startReading()
            }

            tabScope.removeAll()
            currentTab?.$canGoBack.sink { v in
                self.canGoBack = v
            }.store(in: &tabScope)
            currentTab?.$canGoForward.sink { v in
                self.canGoForward = v
            }.store(in: &tabScope)

            resetDestinationCard()
        }
    }

    @Published var currentPage: WindowPage?

    private var scope = Set<AnyCancellable>()
    private var tabScope = Set<AnyCancellable>()

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
        guard let note = currentTab?.note else { return }

        switch mode {
        case .web:
            navigateToNote(note)
        case .today, .note, .page:
            if !tabs.isEmpty { mode = .web }
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

    @discardableResult func navigateToNote(named: String) -> Bool {
        //Logger.shared.logDebug("load note named \(named)")
        let note = BeamNote.fetchOrCreate(data.documentManager, title: named)
        return navigateToNote(note)
    }

    @discardableResult func navigateToNote(_ note: BeamNote) -> Bool {
        mode = .note

        guard note != self.currentNote else { return true }

        self.currentPage = nil
        self.currentNote = note
        autocompleteManager.resetQuery()
        autocompleteManager.autocompleteSelectedIndex = nil

        backForwardList.push(.note(note))
        updateCanGoBackForward()
        return true
    }

    @discardableResult func navigateToJournal() -> Bool {
        mode = .today

        self.currentPage = nil
        self.currentNote = nil
        autocompleteManager.resetQuery()
        autocompleteManager.autocompleteSelectedIndex = nil

        backForwardList.push(.journal)
        updateCanGoBackForward()
        return true
    }

    func navigateToPage(_ page: WindowPage) {
        mode = .page

        self.currentNote = nil
        autocompleteManager.resetQuery()
        autocompleteManager.autocompleteSelectedIndex = nil
        focusOmniBox = false
        self.currentPage = page
        backForwardList.push(.page(page))
        updateCanGoBackForward()
    }

    func navigateCurrentTab(toURL url: URL) {
        currentTab?.load(url: url)
    }

    func createTabFromNote(_ note: BeamNote, element: BeamElement, withURL url: URL) {
        let tab = BrowserTab(state: self, originalQuery: note.title, note: note, rootElement: element)
        tab.load(url: url)
        currentTab = tab
        tabs.append(tab)
        mode = .web
    }

    func createTab(withURL url: URL, originalQuery: String, createNote: Bool = true) {
        let tab = BrowserTab(state: self, originalQuery: originalQuery, note: data.todaysNote)
        tab.load(url: url)
        currentTab = tab
        tabs.append(tab)
        mode = .web
    }

    func createEmptyTab() {
        let tab = BrowserTab(state: self, originalQuery: nil, note: data.todaysNote)
        currentTab = tab
        tabs.append(tab)
        mode = .web
    }

    func createTabFromNode(_ node: TextNode, withURL url: URL) {
        guard let note = node.root?.note else { return }
        let tab = BrowserTab(state: self, originalQuery: node.strippedText, note: note, rootElement: node.element, createBullet: false)
        tab.load(url: url)
        currentTab = tab
        tabs.append(tab)
        mode = .web
    }

    func createNoteForQuery(_ query: String) -> BeamNote {
        if let n = BeamNote.fetch(data.documentManager, title: query) {
            return n
        }

        let n = BeamNote.create(data.documentManager, title: query)

        let e = BeamElement()
        e.text = BeamText(text: query, attributes: [.internalLink(query)])
        self.data.todaysNote.insert(e, after: self.data.todaysNote.children.last)

        return n
    }

    private func urlFor(query: String) -> URL {
        //TODO make a better url detector and rewritter to transform xxx.com in https://xxx.com with less corner cases and clearer code path:
        if query.maybeURL {
            guard let u = URL(string: query) else {
                searchEngine.query = query
                return URL(string: searchEngine.searchUrl)!
            }
            return u.urlWithScheme
        }

        searchEngine.query = query
        return URL(string: searchEngine.searchUrl)!
    }

    func startQuery(_ node: TextNode) {
        let query = node.currentSelectionWithFullSentences()
        guard !query.isEmpty else { return }

        createTabFromNode(node, withURL: urlFor(query: query))
        mode = .web
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
                createTab(withURL: url, originalQuery: result.text)
                mode = .web
            }

        case .history, .url:
            let url = result.url?.urlWithScheme ?? urlFor(query: result.text)
            createTab(withURL: url, originalQuery: "")
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
        autocompleteManager.searchQuery = ""
        focusOmniBox = false
        if let index = autocompleteManager.autocompleteSelectedIndex {
            let result = autocompleteManager.autocompleteResults[index]
            selectAutocompleteResult(result)
            return
        }

        let createNote = !queryString.maybeURL
        let url: URL = urlFor(query: queryString)

        // Logger.shared.logDebug("Start query: \(url)")

        if mode == .web, currentTab != nil {
            navigateCurrentTab(toURL: url)
        } else {
            createTab(withURL: url, originalQuery: queryString, createNote: createNote)
        }
        autocompleteManager.cancelAutocomplete()
        mode = .web
    }

    override public init() {
        self.data = AppDelegate.main.data
        super.init()
        setup(data: data)
    }

    enum CodingKeys: String, CodingKey {
        case currentNote
        case mode
        case tabs
        case currentTab
        case backForwardList
    }

    required public init(from decoder: Decoder) throws {
        self.data = AppDelegate.main.data
        super.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let currentNoteTitle = try? container.decode(String.self, forKey: .currentNote) {
            currentNote = BeamNote.fetch(data.documentManager, title: currentNoteTitle)
        }
        backForwardList = try container.decode(NoteBackForwardList.self, forKey: .backForwardList)

        tabs = try container.decode([BrowserTab].self, forKey: .tabs)
        if let tabIndex = try? container.decode(Int.self, forKey: .currentTab), tabIndex < tabs.count {
            currentTab = tabs[tabIndex]
        }

        setup(data: data)
        mode = try container.decode(Mode.self, forKey: .mode)

        for tab in tabs {
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
        try container.encode(tabs, forKey: .tabs)
        if let tab = currentTab {
            try container.encode(tabs.firstIndex(of: tab), forKey: .currentTab)
        }
    }

    func setup(data: BeamData) {
        destinationCardName = data.todaysName
        backForwardList.push(.journal)
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies({ [weak self] cookies in
            guard let self = self else { return }

            for cookie in cookies {
                self.data.cookies.setCookie(cookie)
            }
        })
    }

    func setup(webView: WKWebView) {
        for cookie in self.data.cookies.cookies ?? [] {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        webView.configuration.websiteDataStore.httpCookieStore.add(self)
    }

    func generateTabs(_ number: Int = 100) {
        for _ in 0..<number {
            createTab(withURL: URL(string: "https://beamapp.co")!, originalQuery: "beamapp.co")
        }
    }

    func startNewSearch() {
        autocompleteManager.cancelAutocomplete()
        autocompleteManager.resetQuery()
        if mode == .web {
            createEmptyTab()
        }
        focusOmniBox = true
    }

    func showNextTab() {
        guard let tab = currentTab, let i = tabs.firstIndex(of: tab) else { return }
        let index = (i + 1) % tabs.count
        currentTab = tabs[index]
    }

    func showPreviousTab() {
        guard let tab = currentTab, let i = tabs.firstIndex(of: tab) else { return }
        let index = i - 1 < 0 ? tabs.count - 1 : i - 1
        currentTab = tabs[index]
    }

    func closeCurrentTab() -> Bool {
        guard mode == .web, let tab = currentTab else { return false }
        tab.cancelObservers()

        if let i = tabs.firstIndex(of: tab) {
            tabs.remove(at: i)
            let nextTabIndex = min(i, tabs.count - 1)
            if nextTabIndex >= 0 {
                currentTab = tabs[nextTabIndex]
            }

            if tabs.isEmpty {
                if let note = currentNote {
                    navigateToNote(note)
                } else {
                    navigateToJournal()
                }
                currentTab = nil
            }
            return true
        }

        return false
    }

    @discardableResult
    func removeTab(_ index: Int) -> Bool {
        let tab = tabs[index]
        guard currentTab !== tab else { return closeCurrentTab() }

        tab.cancelObservers()
        tabs.remove(at: index)

        return true
    }

    func resetDestinationCard() {
        destinationCardName = currentTab?.note.title ?? data.todaysName
        destinationCardNameSelectedRange = nil
        destinationCardIsFocused = false
    }
}
