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

enum Mode {
    case today
    case note
    case web
}

var runningOnBigSur: Bool = {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)
}()

@objc class BeamState: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    var data: BeamData
    public var searchEngine: SearchEngine = GoogleSearch()

    @Published var searchQuery: String = ""
    @Published var searchQuerySelection: [Range<Int>]?
    @Published var completedQueries = [AutoCompleteResult]()
    @Published var currentNote: BeamNote?
    @Published var backForwardList: NoteBackForwardList
    @Published var isEditingOmniBarTitle = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isFullScreen: Bool = false

    @Published var mode: Mode = .today {
        didSet {
            switch oldValue {
            // swiftlint:disable:next fallthrough no_fallthrough_only
            case .note: fallthrough
            case .today:
                if mode == .web {
                    currentTab?.startViewing()
                }

            case .web:
                currentTab?.stopViewing()
            }
            updateCanGoBackForward()
        }
    }

    @Published var selectionIndex: Int? = nil {
        didSet {
            if let i = selectionIndex, i >= 0, i < completedQueries.count {
                let completedQuery = completedQueries[i].string
                let oldSize = searchQuerySelection?.first?.startIndex ?? searchQuery.count
                let newSize = completedQuery.count
                // If the completion shares a common root with the original query, select the portion that is different
                // otherwise select the whole string so that the next keystroke replaces everything
                let newSelection = [(completedQuery.hasPrefix(searchQuery.substring(from: 0, to: oldSize)) ? oldSize : 0) ..< newSize]
                searchQuery = completedQuery
                searchQuerySelection = newSelection
            }
        }
    }

    @Published public var tabs: [BrowserTab] = [] {
        didSet {
            for tab in tabs {
                tab.onNewTabCreated = { [weak self] newTab in
                    guard let self = self else { return }
                    self.tabs.append(newTab)

//                    if var note = self.currentNote {
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
                    self.data.searchKit.append(url: url, contents: read.title + "\n" + read.siteName + "\n" + read.textContent)
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
                oldValue?.stopViewing()
                currentTab?.startViewing()
            }

            tabScope.removeAll()
            currentTab?.$canGoBack.sink { v in
                self.canGoBack = v
            }.store(in: &tabScope)
            currentTab?.$canGoForward.sink { v in
                self.canGoForward = v
            }.store(in: &tabScope)

            isEditingOmniBarTitle = false
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
                    currentNote = note
                    mode = .note
                }
            }
        case .web:
            currentTab?.webView.goBack()
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
                    currentNote = note
                    mode = .note
                }
            }
        case .web:
            currentTab?.webView.goForward()
        }
        updateCanGoBackForward()
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

    func selectPreviousAutoComplete() {
        if let i = selectionIndex {
            let newIndex = i - 1
            if newIndex >= 0 {
                selectionIndex = newIndex
            } else {
                selectionIndex = nil
            }
        } else {
            let newIndex = completedQueries.count - 1
            if newIndex >= 0 {
                selectionIndex = newIndex
            } else {
                selectionIndex = nil
            }
        }
    }

    func selectNextAutoComplete() {
        if let i = selectionIndex {
            selectionIndex = min(i + 1, completedQueries.count - 1)
        } else {
            selectionIndex = 0
        }
    }

    @discardableResult func navigateToNote(named: String) -> Bool {
//        print("load note named \(named)")
        let note = BeamNote.fetchOrCreate(data.documentManager, title: named)
        return navigateToNote(note)
    }

    @discardableResult func navigateToNote(_ note: BeamNote) -> Bool {
        completedQueries = []
        selectionIndex = nil
        searchQuery = ""
        mode = .note

        self.currentNote = note

        backForwardList.push(.note(note))
        updateCanGoBackForward()
        return true
    }

    @discardableResult func navigateToJournal() -> Bool {
        completedQueries = []
        selectionIndex = nil
        searchQuery = ""
        mode = .today

        self.currentNote = nil

        backForwardList.push(.journal)
        updateCanGoBackForward()
        return true
    }

    func createTab(withURL url: URL, originalQuery: String, createNote: Bool = true) {
        let note = createNote ? (originalQuery.isEmpty ? data.todaysNote : createNoteForQuery(originalQuery)) : data.todaysNote
        let tab = BrowserTab(state: self, originalQuery: originalQuery, note: note)
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

        let bulletStr = "[[\(query)]]"
        let e = BeamElement()
        e.text = bulletStr
        self.data.todaysNote.insert(e, after: self.data.todaysNote.children.last)

        return n
    }

    private func urlFor(query: String) -> URL {
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
        let query = node.strippedText
        guard !query.isEmpty else { return }

        createTabFromNode(node, withURL: urlFor(query: query))
        mode = .web
    }

    func startQuery() {
        if let index = selectionIndex {
            let query = completedQueries[index]
            switch query.source {
            case .autoComplete:
                searchEngine.query = query.string
//                print("Start search query: \(searchEngine.searchUrl)")
                createTab(withURL: URL(string: searchEngine.searchUrl)!, originalQuery: query.string)
                mode = .web

            case .history:
                createTab(withURL: URL(string: query.string)!, originalQuery: "")
                mode = .web

            case .note:
                navigateToNote(named: searchQuery)
            }

            cancelAutocomplete()
            return
        }

        var createNote = true
        //TODO make a better url detector and rewritter to transform xxx.com in https://xxx.com with less corner cases and clearer code path:
        let url: URL = {
            if searchQuery.maybeURL {
                guard let u = URL(string: searchQuery) else {
                    searchEngine.query = searchQuery
                    return URL(string: searchEngine.searchUrl)!
                }

                if u.scheme == nil {
                    createNote = false
                    return URL(string: "https://" + searchQuery)!
                }
                return u
            }
            searchEngine.query = searchQuery
            return URL(string: searchEngine.searchUrl)!
        }()
//        print("Start query: \(url)")

        createTab(withURL: url, originalQuery: searchQuery, createNote: createNote)
        cancelAutocomplete()
        mode = .web
    }

    public init(data: BeamData) {
        self.data = data
//        self.currentNote = data.todaysNote
        backForwardList = NoteBackForwardList()
        super.init()
        $searchQuery.sink { [weak self] query in
            guard let self = self else { return }
            guard self.searchQuerySelection == nil else { return }
            guard self.selectionIndex == nil else { return }
//            print("received auto complete query: \(query)")

            self.completedQueries = []

            if !query.isEmpty {
                let notes = data.documentManager.documentsWithTitleMatch(title: query).prefix(4)
                notes.forEach {
                    let autocompleteResult = AutoCompleteResult(id: $0.id, string: $0.title, source: .note)
                    self.completedQueries.append(autocompleteResult)
//                    print("Found note \($0)")
                }

                self.completer.complete(query: query)
                let urls = self.data.searchKit.search(query)
                for url in urls.prefix(4) {
                    self.completedQueries.append(AutoCompleteResult(id: UUID(), string: url.description, source: .history))
                }
            }
        }.store(in: &scope)

        completer.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self else { return }
            //print("received auto complete results: \(results)")
            self.selectionIndex = nil
            self.completedQueries.append(contentsOf: results.prefix(8))
        }.store(in: &scope)

        backForwardList.push(.journal)

    }

    func resetQuery() {
        searchQuery = ""
        completedQueries = []
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

    func startNewSearch() {
        cancelAutocomplete()
        currentNote = nil
        resetQuery()
        navigateToJournal()
        BNSTextField.focusField(named: "OmniBarSearchBox")
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

    func resetAutocompleteSelection() {
        searchQuerySelection = nil
        selectionIndex = nil
        BNSTextField.focusField(named: "OmniBarSearchBox")
    }

    func cancelAutocomplete() {
        resetAutocompleteSelection()
        completedQueries = []
    }
}
