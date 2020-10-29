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

class BeamData: ObservableObject {
    var _todaysNote: Note?
    var todaysNote: Note {
        if let note = _todaysNote, note.title == todaysName {
            return note
        }

        setupJournal()
        return _todaysNote!
    }
    @Published var journal: [Note] = []

    var searchKit: SearchKit

    init() {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        if let applicationSupportDirectory = paths.first {
            let indexPath = URL(fileURLWithPath: applicationSupportDirectory + "/index.sk")
            searchKit = SearchKit(indexPath)
        } else {
            searchKit = SearchKit(URL(fileURLWithPath: "~/Application Data/BeamApp/index.sk"))
        }
    }

    var todaysName: String {
        let fmt = DateFormatter()
        let today = Date()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: today)
    }

    func setupJournal() {
        if let note = Note.fetchWithTitle(CoreDataManager.shared.mainContext, todaysName) {
            print("Today's note loaded:\n\(note)\n")
            _todaysNote = note
        } else {
            let note = Note.createNote(CoreDataManager.shared.mainContext, todaysName)
            note.type = NoteType.journal.rawValue
            let bullet = note.createBullet(CoreDataManager.shared.mainContext, content: "")
            note.addToBullets(bullet)
            _todaysNote = note
            print("Today's note created:\n\(note)\n")

            CoreDataManager.shared.save()
        }

        updateJournal()
    }

    func updateJournal() {
        journal = Note.fetchAllWithType(CoreDataManager.shared.mainContext, .journal)
        print("Journal updated:\n\(journal)\n")
    }
}

class BeamState: ObservableObject {
    @Published var mode: Mode = .note {
        didSet {
            updateCanGoBackForward()
        }
    }

    func updateCanGoBackForward() {
        switch mode {
        case .note:
            canGoBack = !backForwardList.backList.isEmpty
            canGoForward = !backForwardList.forwardList.isEmpty
        case .web:
            canGoBack = currentTab.canGoBack
            canGoForward = currentTab.canGoForward
        case .today:
            canGoBack = false
            canGoForward = false
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
                mode = .note
            }
        }
    }
    @Published var currentTab = BrowserTab(originalQuery: "") // Fake empty tab by default
    {
        didSet {
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
        case .note:
            currentNote = backForwardList.goBack()
        case .web:
            currentTab.webView.goBack()
        case .today:
            break
        }
        updateCanGoBackForward()
    }

    func goForward() {
        guard canGoForward else { return }
        switch mode {
        case .note:
            currentNote = backForwardList.goForward()
        case .web:
            currentTab.webView.goForward()
        case .today:
            break
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

    func navigateToNote(named: String) -> Bool {
        print("load note named \(named)")
        guard let note = Note.fetchWithTitle(CoreDataManager.shared.mainContext, named) else { return false }
        completedQueries = []
        selectionIndex = nil
        searchQuery = ""
        mode = .note

        self.currentNote = note
        backForwardList.push(note: note)
        updateCanGoBackForward()
        return true
    }

    func createTab(withURL url: URL, originalQuery: String) {
        let tab = BrowserTab(originalQuery: originalQuery)
        tab.load(url: url)
        currentTab = tab
        tabs.append(tab)
        mode = .web
    }

    func startQuery() {
        let query = searchQuery
        var searchText = query
        let url = URL(string: searchText)

        if url?.scheme == nil {
            if navigateToNote(named: searchQuery) {
                return
            }

            searchEngine.query = searchText
            searchText = searchEngine.searchUrl
            print("Start search query: \(searchText)")
        }

        createTab(withURL: URL(string: searchText)!, originalQuery: query)
//        currentNote = Note.createNote(CoreDataManager.shared.mainContext, query)
        mode = .web
    }

    private var scope = Set<AnyCancellable>()

    public init(data: BeamData) {
        self.data = data
//        self.currentNote = data.todaysNote
        backForwardList = NoteBackForwardList()

        $searchQuery.sink { [weak self] query in
            guard let self = self else { return }
            guard self.searchQuerySelection == nil else { return }
            guard self.selectionIndex == nil else { return }
            print("received auto complete query: \(query)")

            if !(query.hasPrefix("http://") || query.hasPrefix("https://")) {
                self.mode = .note
            }
            self.completedQueries = []

            if !query.isEmpty {
                let notes = Note.fetchAllWithTitleMatch(CoreDataManager.shared.mainContext, query)
                notes.forEach {
                    let autocompleteResult = AutoCompleteResult(id: $0.id, string: $0.title, source: .note)
                    self.completedQueries.append(autocompleteResult)
                    print("Found note \($0)")
                }

                self.completer.complete(query: query)
                let urls = self.data.searchKit.search(query)
                for url in urls {
                    self.completedQueries.append(AutoCompleteResult(id: UUID(), string: url.description, source: .history))
                }
            }
        }.store(in: &scope)
        completer.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self else { return }
            //print("received auto complete results: \(results)")
            self.selectionIndex = nil
            self.completedQueries.append(contentsOf: results)
        }.store(in: &scope)
    }

    func resetQuery() {
        searchQuery = ""
        completedQueries = []
    }
}
