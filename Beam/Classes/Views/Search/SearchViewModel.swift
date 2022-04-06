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

    @Published var searchTerms: String {
        didSet {
            typing = true
        }
    }
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

    @Published var positions: [Double]
    @Published var currentPosition: Double
    @Published var pageHeight: Double?
    @Published var incompleteSearch: Bool
    @Published var typing: Bool

    @Published var isEditing: Bool = true

    var didBecomeFirstResponder: Bool

    private var onChange: ((String) -> Void)?
    private var findNext: ((String) -> Void)?
    private var findPrevious: ((String) -> Void)?
    private var done: (() -> Void)?
    var onLocationIndicatorTap: ((Double) -> Void)?

    let context: PresentationContext

    private var scope: Set<AnyCancellable>

    init(context: PresentationContext, terms: String = "", found: Int = 0, onChange: ((String) -> Void)? = nil, onLocationIndicatorTap: ((Double) -> Void)? = nil, next: ((String) -> Void)? = nil, previous: ((String) -> Void)? = nil, done:(() -> Void)? = nil) {
        self.context = context

        self.searchTerms = terms
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

        $searchTerms
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.search()
            }
            .store(in: &scope)
    }

    func search() {
        onChange?(searchTerms)
    }

    func next() {
        findNext?(searchTerms)
    }

    func previous() {
        findPrevious?(searchTerms)
    }

    func close() {
        done?()
    }

    func onCommit(_ modifierFlags: NSEvent.ModifierFlags?) {
        if let modifiers = modifierFlags, modifiers.contains(.shift) {
            previous()
        } else {
            next()
        }
    }
}
