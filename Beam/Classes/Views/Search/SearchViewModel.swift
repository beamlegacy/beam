//
//  SearchViewModel.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 17/08/2021.
//

import Foundation
import Combine

class SearchViewModel: ObservableObject {

    enum PresentationContext {
        case web
        case card
    }

    @Published private(set) var searchTerms: String

    @Published var foundOccurences: Int {
        didSet {
            typing = false
        }
    }
    @Published var currentOccurence: Int {
        didSet {
            guard foundOccurences > 0 else { return }
            if currentOccurence >= foundOccurences {
                currentOccurence = 0
            } else if currentOccurence < 0 {
                currentOccurence = foundOccurences - 1
            }
        }
    }

    @Published var showPanel: Bool = false

    @Published var positions: [Double]
    @Published var currentPosition: Double
    @Published var pageHeight: Double?
    @Published var incompleteSearch: Bool
    @Published var typing: Bool

    @Published var isEditing: Bool = true
    @Published var selectAll: Bool = false

    @Published var searching: Bool = false

    var didBecomeFirstResponder: Bool

    private var onChange: ((String) -> Void)?
    private var findNext: ((String) -> Void)?
    private var findPrevious: ((String) -> Void)?
    private var done: (() -> Void)?
    var onLocationIndicatorTap: ((Double) -> Void)?

    let context: PresentationContext

    private let searchTermsDebouncer = PassthroughSubject<String, Never>()

    private var didBecomeActiveObserver: Any?

    private var scope: Set<AnyCancellable>

    init(context: PresentationContext, found: Int = 0, onChange: ((String) -> Void)? = nil, onLocationIndicatorTap: ((Double) -> Void)? = nil, next: ((String) -> Void)? = nil, previous: ((String) -> Void)? = nil, done:(() -> Void)? = nil) {
        self.context = context

        self.searchTerms = NSPasteboard(name: .find).string(forType: .string) ?? ""
        self.foundOccurences = found
        self.currentOccurence = 0

        self.findNext = next
        self.findPrevious = previous
        self.done = done
        self.onChange = onChange
        self.onLocationIndicatorTap = onLocationIndicatorTap

        self.positions = []
        self.currentPosition = 0.0

        self.incompleteSearch = false

        self.didBecomeFirstResponder = false

        self.scope = []
        self.typing = false

        didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                                         object: nil,
                                                                         queue: .main) { [weak self] notification in
            self?.updateSearchTermsFromPasteboard()
        }

        searchTermsDebouncer
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] searchTerms in
                guard let self = self else { return }
                self.sendSearchTerms()
            }
            .store(in: &scope)
    }

    deinit {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func sendSearchTerms() {
        let pboard = NSPasteboard(name: .find)
        pboard.clearContents()
        pboard.setString(searchTerms, forType: .string)

        if self.showPanel || self.searching {
            self.search()
        }
    }

    func setSearchTerms(_ terms: String, debounce: Bool) {
        searchTerms = terms
        typing = true

        if debounce {
            searchTermsDebouncer.send(terms)
        } else {
            sendSearchTerms()
        }
    }

    func search() {
        searching = true
        onChange?(searchTerms)
    }

    func next() {
        if searching {
            findNext?(searchTerms)
        } else {
            search()
        }
    }

    func previous() {
        if searching {
            findPrevious?(searchTerms)
        } else {
            search()
        }
    }

    func close() {
        showPanel = false
        searching = false
        done?()
    }

    func onCommit(_ modifierFlags: NSEvent.ModifierFlags?) {
        if let modifiers = modifierFlags, modifiers.contains(.shift) {
            previous()
        } else {
            next()
        }
    }

    private func updateSearchTermsFromPasteboard() {
        if let string = NSPasteboard(name: .find).string(forType: .string),
           searchTerms != string {
            setSearchTerms(string, debounce: false)
        }
    }
}
