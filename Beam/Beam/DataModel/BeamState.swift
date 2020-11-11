//
//  BeamState.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

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
    @Published var mode: Mode = .today {
        didSet {
            switch oldValue {
            // swiftlint:disable:next fallthrough no_fallthrough_only
            case .note: fallthrough
            case .today:
                if mode == .web {
                    currentTab.startViewing()
                }

            case .web:
                currentTab.stopViewing()
            }
            updateCanGoBackForward()
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
            canGoBack = currentTab.canGoBack
            canGoForward = currentTab.canGoForward
        }
    }

    @Published var searchQuery: String = ""
    @Published var searchQuerySelection: [Range<Int>]?
    private let completer = Completer()
    @Published var completedQueries = [AutoCompleteResult]()
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

    var data: BeamData
    @Published var currentNote: Note?
    @Published var backForwardList: NoteBackForwardList

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
    @Published var currentTab: BrowserTab {
        didSet {
            if self.mode == .web {
                oldValue.stopViewing()
                currentTab.startViewing()
            }

            tabScope.removeAll()
            currentTab.$canGoBack.sink { v in
                self.canGoBack = v
            }.store(in: &tabScope)
            currentTab.$canGoForward.sink { v in
                self.canGoForward = v
            }.store(in: &tabScope)
        }
    }

    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

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
            currentTab.webView.goBack()
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
            currentTab.webView.goForward()
        }
        updateCanGoBackForward()
    }

    private var tabScope = Set<AnyCancellable>()

    public var searchEngine: SearchEngine = GoogleSearch()

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
        print("load note named \(named)")
        guard let note = Note.fetchWithTitle(CoreDataManager.shared.mainContext, named) else { return false }
        return navigateToNote(note)
    }

    @discardableResult func navigateToNote(_ note: Note) -> Bool {
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

    func createTab(withURL url: URL, originalQuery: String) {
        let note = originalQuery.isEmpty ? nil : createNoteForQuery(originalQuery)
        let tab = BrowserTab(state: self, originalQuery: originalQuery, note: note)
        tab.load(url: url)
        currentTab = tab
        tabs.append(tab)
        mode = .web
    }

    func createNoteForQuery(_ query: String) -> Note {
        let context = CoreDataManager.shared.mainContext
        if let n = Note.fetchWithTitle(context, query) {
            return n
        }

        let n = Note.createNote(context, query)
        n.score = Float(0) as NSNumber

        let bulletStr = "Created [[\(query)]]"
        if let bullet = self.data.todaysNote.rootBullets().first, bullet.content.isEmpty {
            bullet.content = bulletStr
        } else {
            let bullet = self.data.todaysNote.createBullet(context, content: bulletStr)
            bullet.score = Float(0) as NSNumber
        }

        return n
    }

    func startQuery() {
        if let index = selectionIndex {
            let query = completedQueries[index]
            switch query.source {
            case .autoComplete:
                searchEngine.query = query.string
                print("Start search query: \(searchEngine.searchUrl)")
                createTab(withURL: URL(string: searchEngine.searchUrl)!, originalQuery: query.string)
                mode = .web

            case .history:
                createTab(withURL: URL(string: query.string)!, originalQuery: "")
                mode = .web

            case .note:
                navigateToNote(named: searchQuery)
            }

            return
        }

        let url: URL = {
            if searchQuery.maybeURL {
                guard let u = URL(string: searchQuery) else {
                    return URL(string: "https://" + searchQuery)!
                }

                if u.scheme == nil {
                    return URL(string: "https://" + searchQuery)!
                }
                return u
            }
            searchEngine.query = searchQuery
            return URL(string: searchEngine.searchUrl)!
        }()
        print("Start query: \(url)")

        createTab(withURL: url, originalQuery: searchQuery)
        cancelAutocomplete()
        mode = .web
    }

    private var scope = Set<AnyCancellable>()

    public init(data: BeamData) {
        self.data = data
//        self.currentNote = data.todaysNote
        backForwardList = NoteBackForwardList()
        currentTab = BrowserTab()
        super.init()
        $searchQuery.sink { [weak self] query in
            guard let self = self else { return }
            guard self.searchQuerySelection == nil else { return }
            guard self.selectionIndex == nil else { return }
            print("received auto complete query: \(query)")

            self.completedQueries = []

            if !query.isEmpty {
                let notes = Note.fetchAllWithTitleMatch(CoreDataManager.shared.mainContext, query).prefix(4) // limit to 8 results
                notes.forEach {
                    let autocompleteResult = AutoCompleteResult(id: $0.id, string: $0.title, source: .note)
                    self.completedQueries.append(autocompleteResult)
                    print("Found note \($0)")
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
        if let i = tabs.firstIndex(of: currentTab) {
            let i = (i + 1) % tabs.count
            currentTab = tabs[i]
        }
    }

    func showPreviousTab() {
        if let i = tabs.firstIndex(of: currentTab) {
            let i = i - 1 < 0 ? tabs.count - 1 : i - 1
            currentTab = tabs[i]
        }
    }

    func closeCurrentTab() -> Bool {
        if mode == .web {
            if let i = tabs.firstIndex(of: currentTab) {
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
                }
                return true
            }
        }

        return false
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
