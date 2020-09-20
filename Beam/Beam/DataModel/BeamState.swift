//
//  BeamState.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import Combine

enum Mode {
    case history
    case note
    case web
}

class BeamState: ObservableObject {
    static var shared: BeamState = BeamState()
    @Published var mode: Mode = .note
    @Published var webViewStore: WebViewStore = WebViewStore()
    @Published var searchQuery: String = ""
    private let completer = Completer()
    @Published var completedQueries = [AutoCompleteResult]()
    @Published var selectionIndex = 0

    private var cancellables = [Cancellable]()
    init() {
        cancellables.append($searchQuery.sink { [weak self] query in
            guard let self = self else { return }
//            print("received auto complete query: \(query)")

            self.selectionIndex = 0
            if !(query.hasPrefix("http://") || query.hasPrefix("https://")) {
                self.mode = .note
            }
            self.completer.complete(query: query)
        })
        cancellables.append(completer.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self else { return }
//            print("received auto complete results: \(results)")
            self.completedQueries = results
        })
    }
}
