//
//  BeamTextEdit+Search.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 04/10/2021.
//

import Foundation

// MARK: - Search
public extension ElementNode {

    func allElementsContaining(someText: String) -> [SearchResult] {

        var results = [SearchResult]()
        self.searchHighlightRanges = []
        if let textNode = self as? TextNode {
            let ranges = textNode.text.text.countInstances(of: someText)
            if !ranges.isEmpty {
                results.append(SearchResult(element: self, ranges: ranges))
                self.searchHighlightRanges = ranges.map({ Range($0) }).compactMap({ $0 })
            }
        }

        for c in children where c is TextNode {
            guard let c = c as? TextNode else { continue }
            let elements = c.allElementsContaining(someText: someText)
            if !elements.isEmpty {
                results.append(contentsOf: elements)
            }
        }

        return results
    }

    func clearSearch() {
        self.searchHighlightRanges = []
        self.currentSearchHightlight = nil
        for c in children {
            if let c = c as? TextNode {
                c.clearSearch()
            }
        }
    }
}

extension BeamTextEdit {

    func searchInNote(fromSelection: Bool) {

        guard searchViewModel == nil else {
            searchViewModel?.searchTerms = fromSelection ? self.selectedText : searchViewModel!.searchTerms
            searchViewModel?.isEditing = true
            return
        }

        let viewModel = SearchViewModel(context: .card) { [weak self] search in
            self?.performSearchAndUpdateUI(with: search)
        } onLocationIndicatorTap: { [weak self] location in
            self?.scroll(NSPoint(x: 0, y: location))
        } next: { [weak self] _ in
            guard let vm = self?.searchViewModel else { return }
            vm.currentOccurence += 1
            self?.highlightCurrentSearchResult(for: vm.currentOccurence)
            self?.rootNode?.deepInvalidateText()
        } previous: { [weak self] _ in
            guard let vm = self?.searchViewModel else { return }
            vm.currentOccurence -= 1
            self?.highlightCurrentSearchResult(for: vm.currentOccurence)
            self?.rootNode?.deepInvalidateText()
        } done: {  [weak self] in
            self?.cancelSearch()
        }

        self.searchViewModel = viewModel

        if fromSelection {
            self.searchViewModel?.searchTerms = self.selectedText
        }
    }

    private func performSearchAndUpdateUI(with search: String) {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let vm = self.searchViewModel, let results = self.rootNode?.allElementsContaining(someText: search) else { return }

            let nodeWithResults = Set(results.map({ $0.element }))
            var nodesWithOutdatedResults: Set<ElementNode> = []
            if let oldResults = self.searchResults {
                let oldNodeWithResults = Set(oldResults.map({ $0.element }))
                nodesWithOutdatedResults = oldNodeWithResults.subtracting(nodeWithResults)
            }
            self.searchResults = results

            var positions = Set<Double>()
            results.forEach({
                positions.formUnion($0.getPositions())
            })

            let foundOccurences = results.reduce(0, { previous, searchResult in
                previous + searchResult.ranges.count
            })

            DispatchQueue.main.async {
                vm.currentOccurence = 0
                vm.foundOccurences = foundOccurences
                self.highlightCurrentSearchResult(for: vm.currentOccurence, scrollingToHighlight: false)

                nodeWithResults.union(nodesWithOutdatedResults).forEach({
                    $0.invalidateText()
                })

                vm.positions = Array(positions)
                vm.pageHeight = Double(self.frame.size.height)
            }
        }
    }

    func cancelSearch() {
        self.rootNode?.clearSearch()
        self.rootNode?.deepInvalidateText()
        self.searchViewModel = nil
        self.searchResults = nil
    }

    private func highlightCurrentSearchResult(for position: Int, scrollingToHighlight: Bool = true) {
        guard let searchResults = searchResults else { return }

        var offset = position + 1
        var nodeIndex = 0
        while offset != 0 {
            guard nodeIndex < searchResults.count else { return }
            let currentResult = searchResults[nodeIndex]
            let rangeCount = currentResult.ranges.count
            let road =  offset - rangeCount
            guard road <= 0 else {
                nodeIndex += 1
                offset = road
                continue
            }

            searchResults.map({ $0.element }).forEach({
                $0.currentSearchHightlight = nil
                $0.allParents.forEach { ($0 as? ElementNode)?.unfold() }
                $0.unfold()
            })
            let rangeIndex = offset-1
            currentResult.element.currentSearchHightlight = rangeIndex
            let highlightedVerticalPosition = currentResult.getPositions()[rangeIndex]
            self.searchViewModel?.currentPosition = highlightedVerticalPosition
            if scrollingToHighlight {
                showElement(at: highlightedVerticalPosition, inElementWithId: note.id, unfold: true)
            }
            break
        }
    }
}
