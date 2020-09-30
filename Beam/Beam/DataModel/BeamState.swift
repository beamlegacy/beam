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
    case note
    case web
}

class BeamData {
    @Published var notes: BeamNotes = BeamNotes()
    @Published var todaysNote: BeamNote
    
    var searchKit: SearchKit
    
    init() {
        let fmt = DateFormatter()
        let today = Date()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        let todayStr = fmt.string(from: today)
        todaysNote = BeamNote(title: todayStr)
        
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        if let applicationSupportDirectory = paths.first {
            let indexPath = URL(fileURLWithPath: applicationSupportDirectory + "/index.sk")
            searchKit = SearchKit(indexPath)
        } else {
            searchKit = SearchKit(URL(fileURLWithPath: "~/Application Data/BeamApp/index.sk"))

        }
    }
}

class BeamState: ObservableObject {
    @Published var mode: Mode = .note
    @Published var searchQuery: String = ""
    private let completer = Completer()
    @Published var completedQueries = [AutoCompleteResult]()
    @Published var selectionIndex: Int? = nil {
        didSet {
            if let i = selectionIndex {
                searchQuery = completedQueries[i].string
            }
        }
    }
    
    var data: BeamData
    @Published var currentNote: BeamNote? = nil
    
    @Published public var tabs: [BrowserTab] = [] {
        didSet {
            for tab in tabs {
                tab.onNewTabCreated = { [weak self] newTab in
                    guard let self = self else { return }
                    self.tabs.append(newTab)
                    
                    if var note = self.currentNote {
                        if note.searchQueries.contains(newTab.originalQuery) {
                            if let url = newTab.url {
                                note.visitedSearchResults.append(VisitedPage(originalSearchQuery: newTab.originalQuery, url: url, date: Date(), duration: 0))
                                self.currentNote = note
                            }
                        }
                    }
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

    private var scope = Set<AnyCancellable>()

    public init(data: BeamData) {
        self.data = data
        self.currentNote = data.todaysNote
        $searchQuery.sink { [weak self] query in
            guard let self = self else { return }
            //print("received auto complete query: \(query)")

            if !(query.hasPrefix("http://") || query.hasPrefix("https://")) {
                self.mode = .note
            }
            self.completedQueries = []
            self.completer.complete(query: query)
            let urls = self.data.searchKit.search(query)
            for u in urls {
                self.completedQueries.append(AutoCompleteResult(id: UUID(), string: u.description, source: .history))
            }
        }.store(in: &scope)
        completer.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self else { return }
            //print("received auto complete results: \(results)")
            self.selectionIndex = nil
            self.completedQueries.append(contentsOf: results)
        }.store(in: &scope)

    }
}
