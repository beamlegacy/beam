//
//  SearchViewModel.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 17/08/2021.
//

import Foundation

class SearchViewModel: ObservableObject {

    enum PresentationContext {
        case web
        case card
    }

    @Published var searchTerms: String {
        didSet {
            onChange?(searchTerms)
        }
    }
    @Published var foundOccurences: UInt
    @Published var currentOccurence: UInt

    @Published var positions: [Double]
    @Published var currentPosition: Double
    @Published var pageHeight: Double?
    @Published var incompleteSearch: Bool

    var didBecomeFirstResponder: Bool

    var onChange: ((String) -> Void)?
    var findNext: ((String) -> Void)?
    var findPrevious: ((String) -> Void)?
    var onLocationIndicatorTap: ((Double) -> Void)?
    var done: (() -> Void)?

    let context: PresentationContext

    init(context: PresentationContext, terms: String = "", found: UInt = 0, onChange: ((String) -> Void)? = nil, onLocationIndicatorTap: ((Double) -> Void)? = nil, next: ((String) -> Void)? = nil, previous: ((String) -> Void)? = nil, done:(() -> Void)? = nil) {
        self.context = context

        self.searchTerms = terms
        self.foundOccurences = found
        self.currentOccurence = 1

        self.findNext = next
        self.findPrevious = previous
        self.done = done
        self.onChange = onChange
        self.onLocationIndicatorTap = onLocationIndicatorTap

        self.positions = []
        self.currentPosition = 0.0

        self.incompleteSearch = false

        self.didBecomeFirstResponder = false
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
}
