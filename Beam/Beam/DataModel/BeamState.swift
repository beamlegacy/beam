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
    case history
    case note
    case web
}

class BeamState: ObservableObject {
    static var shared: BeamState = BeamState()
    @Published var mode: Mode = .note
    @Published var searchQuery: String = ""
    private let completer = Completer()
    @Published var completedQueries = [AutoCompleteResult]()
    @Published var selectionIndex: Int? = nil
    
    @Published var tabs: [BrowserTab] = []
    @Published var currentTab = BrowserTab() // Fake empty tab by default

    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

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
    
    public init() {
        $searchQuery.sink { [weak self] query in
            guard let self = self else { return }
            //print("received auto complete query: \(query)")

            self.selectionIndex = nil
            if !(query.hasPrefix("http://") || query.hasPrefix("https://")) {
                self.mode = .note
            }
            self.completer.complete(query: query)
        }.store(in: &scope)
        completer.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self else { return }
            //print("received auto complete results: \(results)")
            self.completedQueries = results
        }.store(in: &scope)

    }
    
}
