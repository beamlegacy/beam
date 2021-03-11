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

let NoteDisplayThreshold = Float(0.0)
//swiftlint:disable:next type_body_length
@objc class BeamState: NSObject, ObservableObject, WKHTTPCookieStoreObserver, Codable {
    var data: BeamData
    public var searchEngine: SearchEngine = GoogleSearch()

    @Published var searchQuery: String = ""
    @Published var searchQuerySelectedRanges: [Range<Int>]?
    @Published var autocompleteResults = [AutocompleteResult]()
    private var autocompleteSearchGuessesHandler: (([AutocompleteResult]) -> Void)?
    private var autocompleteTimeoutBlock: DispatchWorkItem?

    @Published var currentNote: BeamNote?
    @Published var backForwardList = NoteBackForwardList()
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isFullScreen: Bool = false
    @Published var focusOmniBox: Bool = true

    @Published var destinationCardIsFocused: Bool = false
    @Published var destinationCardName: String
    @Published var destinationCardNameSelectedRange: [Range<Int>]?
    var bidirectionalPopover: BidirectionalPopover?

    @Published var mode: Mode = .today {
        didSet {
            switch oldValue {
            // swiftlint:disable:next fallthrough no_fallthrough_only
            case .note: fallthrough
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
    @Published var autocompleteSelectedIndex: Int? = nil {
        didSet {
            if let i = autocompleteSelectedIndex, i >= 0, i < autocompleteResults.count {
                let resultText = autocompleteResults[i].text
                let oldSize = searchQuerySelectedRanges?.first?.startIndex ?? searchQuery.count
                let newSize = resultText.count
                let unselectedPrefix = searchQuery.substring(from: 0, to: oldSize).lowercased()
                // If the completion shares a common root with the original query, select the portion that is different
                // otherwise select the whole string so that the next keystroke replaces everything
                let newSelection = [(resultText.hasPrefix(unselectedPrefix) ? oldSize : 0) ..< newSize]
                searchQuery = resultText
                searchQuerySelectedRanges = newSelection
            }
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

    private let completer = Completer()
    private var scope = Set<AnyCancellable>()
    private var tabScope = Set<AnyCancellable>()

    func goBack() {
        guard canGoBack else { return }
        switch mode {
        // swiftlint:disable:next fallthrough no_fallthrough_only
        case .note: fallthrough
        case .today:
            if let back = backForwardList.goBack() {
                switch back {
                case .journal:
                    mode = .today
                    currentNote = nil
                case let .note(note):
                    mode = .note
                    currentNote = note
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
        case .note: fallthrough
        case .today:
            if let forward = backForwardList.goForward() {
                switch forward {
                case .journal:
                    mode = .today
                    currentNote = nil
                case let .note(note):
                    mode = .note
                    currentNote = note
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
        case .note:
            mode = .web
        case .today:
            if !tabs.isEmpty { mode = .web }
        }
    }

    func updateCanGoBackForward() {
        switch mode {
        // swiftlint:disable:next fallthrough no_fallthrough_only
        case .today: fallthrough
        case .note:
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

        self.currentNote = note
        resetQuery()
        autocompleteSelectedIndex = nil

        backForwardList.push(.note(note))
        updateCanGoBackForward()
        return true
    }

    @discardableResult func navigateToJournal() -> Bool {
        mode = .today

        self.currentNote = nil
        resetQuery()
        autocompleteSelectedIndex = nil

        backForwardList.push(.journal)
        updateCanGoBackForward()
        return true
    }

    func navigateCurrentTab(toURL url: URL) {
        currentTab?.load(url: url)
    }

    func createTab(withURL url: URL, originalQuery: String, createNote: Bool = true) {
        let tab = BrowserTab(state: self, originalQuery: originalQuery, note: data.todaysNote)
        tab.load(url: url)
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

            if u.scheme == nil {
                return URL(string: "https://" + query)!
            }
            return u
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
            let url = urlFor(query: result.text)
            createTab(withURL: url, originalQuery: "")
            mode = .web

        case .note:
            navigateToNote(named: result.text)

        case .createCard:
            navigateToNote(createNoteForQuery(result.text))
        }
        cancelAutocomplete()
    }

    func startQuery() {
        let queryString = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = ""
        focusOmniBox = false
        if let index = autocompleteSelectedIndex {
            let result = autocompleteResults[index]
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
        cancelAutocomplete()
        mode = .web
    }

    override public init() {
        self.data = AppDelegate.main.data
        self.destinationCardName = data.todaysName
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
        self.destinationCardName = data.todaysName
        super.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let currentNoteName = try? container.decode(String.self, forKey: .currentNote) {
            currentNote = BeamNote.fetch(data.documentManager, title: currentNoteName)
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
        $searchQuery.sink { [weak self] query in
            guard let self = self else { return }
            self.buildAutocompleteResults(for: query)

        }.store(in: &scope)

        completer.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self, let guessesHandler = self.autocompleteSearchGuessesHandler else { return }
            guessesHandler(results)
        }.store(in: &scope)

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
        cancelAutocomplete()
        currentNote = nil
        resetQuery()
        navigateToJournal()
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

// MARK: - Autocomplete
extension BeamState {

    func selectPreviousAutocomplete() {
        if let i = autocompleteSelectedIndex {
            let newIndex = i - 1
            if newIndex >= 0 {
                autocompleteSelectedIndex = newIndex
            } else {
                resetAutocompleteSelection()
            }
        } else {
            autocompleteSelectedIndex = (-1).clampInLoop(0, autocompleteResults.count - 1)
        }
    }

    func selectNextAutocomplete() {
        if let i = autocompleteSelectedIndex {
            autocompleteSelectedIndex = (i + 1).clampInLoop(0, autocompleteResults.count - 1)
        } else {
            autocompleteSelectedIndex = 0
        }
    }

    func resetAutocompleteSelection() {
        searchQuerySelectedRanges = nil
        autocompleteSelectedIndex = nil
    }

    func cancelAutocomplete() {
        resetAutocompleteSelection()
        autocompleteResults = []
    }

    func resetQuery() {
        searchQuery = ""
        autocompleteResults = []
    }

    private func autocompleteNotesResults(for query: String) -> [AutocompleteResult] {
        return data.documentManager.documentsWithTitleMatch(title: query)
            // Eventually, we should not show notes under a certain score threshold
            // Disabling it for now until we have a better scoring system
            // .compactMap({ doc -> DocumentStruct? in
            //      let decoder = JSONDecoder()
            //      decoder.userInfo[BeamElement.recursiveCoding] = false
            //      guard let note = try? decoder.decode(BeamNote.self, from: doc.data)
            //      else { Logger.shared.logError("unable to partially decode note '\(doc.title)'", category: .document); return nil }
            //      Logger.shared.logDebug("Filtering note '\(note.title)' -> \(note.score)", category: .general)
            //      return note.score >= NoteDisplayThreshold ? doc : nil
            // })
            .map { AutocompleteResult(text: $0.title, source: .note, completingText: query, uuid: $0.id) }
    }

    private func autocompleteHistoryResults(for query: String) -> [AutocompleteResult] {
        return self.data.index.search(string: query).map { AutocompleteResult(text: $0.source, source: .history, information: $0.title, completingText: query) }
    }

    func buildAutocompleteResults(for query: String) {
        guard self.searchQuerySelectedRanges == nil else { return }
        guard self.autocompleteSelectedIndex == nil else { return }
        // Logger.shared.logDebug("received auto complete query: \(query)")

        guard !query.isEmpty else {
            self.autocompleteResults = []
            return
        }
        var finalResults = [AutocompleteResult]()

        // #1 Exisiting Notes
        let notesResults = autocompleteNotesResults(for: query)

        // #2 History results
        let historyResults = autocompleteHistoryResults(for: query)

        finalResults = sortResults(notesResults: notesResults, historyResults: historyResults)

        // #3 Create Card
        let canCreateNote = BeamNote.fetch(data.documentManager, title: query) == nil
        if canCreateNote {
            // if the card doesn't exist, propose to create it
            finalResults.append(AutocompleteResult(text: query, source: .createCard, information: "New card", completingText: query))
        }

        if query.count > 1 {
            // #4 Search Autocomplete results
            autocompleteSearchGuessesHandler = { [weak self] results in
                guard let self = self else { return }
                //Logger.shared.logDebug("received auto complete results: \(results)")
                self.autocompleteSelectedIndex = nil
                let maxGuesses = finalResults.count > 2 ? 4 : 6
                let toInsert = results.prefix(maxGuesses)
                let atIndex = finalResults.count - (canCreateNote ? 1 : 0)
                if self.autocompleteTimeoutBlock != nil {
                    self.autocompleteTimeoutBlock?.cancel()
                    finalResults.insert(contentsOf: toInsert, at: atIndex)
                    self.autocompleteResults = finalResults
                } else {
                    self.autocompleteResults.insert(contentsOf: toInsert, at: atIndex)
                }
            }
            self.completer.complete(query: query)

            autocompleteTimeoutBlock?.cancel()
            autocompleteTimeoutBlock = DispatchWorkItem(block: {
                self.autocompleteTimeoutBlock = nil
                self.autocompleteResults = finalResults
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: autocompleteTimeoutBlock!)
        } else {
            autocompleteSearchGuessesHandler = nil
            self.autocompleteResults = finalResults
        }
    }

    func sortResults(notesResults: [AutocompleteResult], historyResults: [AutocompleteResult]) -> [AutocompleteResult] {
        // this logic should eventually become smarter to always include the right amount of result per source.

        var results = [AutocompleteResult]()

        let maxHistoryResults = notesResults.isEmpty ? 6 : 4
        let historyResultsTruncated = Array(historyResults.prefix(maxHistoryResults))

        let maxNotesSuggestions = historyResults.isEmpty ? 6 : 4
        let notesResultsTruncated = Array(notesResults.prefix(maxNotesSuggestions))

        results.append(contentsOf: notesResultsTruncated)
        results.append(contentsOf: historyResultsTruncated)

        return results
    }
}
