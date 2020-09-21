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
    @Published var currentTab = UUID() // Fake UUID for the initial current tab
    
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
    
    public func load(url: URL) {
        webView.load(URLRequest(url: url))
    }
    
    @Published public var webView: WKWebView {
        didSet {
            setupObservers()
        }
    }

    @Published var title: String? = nil
    @Published var url: URL? = nil
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false
    @Published var serverTrust: SecTrust? = nil
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList


    private var scope = Set<AnyCancellable>()
    
    public init(webView: WKWebView = WKWebView()) {
        self.webView = webView
        backForwardList = webView.backForwardList
        setupObservers()

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
    
    private func setupObservers() {
        webView.publisher(for: \.title).sink() { v in self.title = v }.store(in: &scope)
        webView.publisher(for: \.url).sink() { v in self.url = v }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink() { v in self.isLoading = v }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink() { v in self.estimatedProgress = v }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent).sink() { v in self.hasOnlySecureContent = v }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink() { v in self.serverTrust = v }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink() { v in self.canGoBack = v }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink() { v in self.canGoForward = v }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink() { v in self.backForwardList = v }.store(in: &scope)
    }

}
