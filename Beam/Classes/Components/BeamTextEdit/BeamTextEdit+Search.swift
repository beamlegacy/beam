//
//  BeamTextEdit+Search.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 04/10/2021.
//

import Foundation

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
            self?.rootNode.deepInvalidateText()
        } previous: { [weak self] _ in
            guard let vm = self?.searchViewModel else { return }
            vm.currentOccurence -= 1
            self?.highlightCurrentSearchResult(for: vm.currentOccurence)
            self?.rootNode.deepInvalidateText()
        } done: {  [weak self] in
            self?.rootNode.clearSearch()
            self?.rootNode.deepInvalidateText()
            self?.searchViewModel = nil
        }

        self.searchViewModel = viewModel

        if fromSelection {
            self.searchViewModel?.searchTerms = self.selectedText
        }
    }

    private func performSearchAndUpdateUI(with search: String) {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let vm = self.searchViewModel else { return }
            let results = self.rootNode.allElementsContaining(someText: search)

            let nodeWithResults = Set(results.map({ $0.element }))
            var nodesWithOutdatedResults: Set<TextNode> = []
            if let oldResults = self.searchResults {
                let oldNodeWithResults = Set(oldResults.map({ $0.element }))
                nodesWithOutdatedResults = oldNodeWithResults.subtracting(nodeWithResults)
            }
            self.searchResults = results

            var positions = Set<Double>()
            results.forEach({
                positions.formUnion($0.getPositions())
            })

            DispatchQueue.main.async {
                vm.currentOccurence = 1
                vm.foundOccurences = UInt(results.reduce(0, { previous, searchResult in
                    previous + searchResult.ranges.count
                }))
                self.highlightCurrentSearchResult(for: vm.currentOccurence, scrollingToHighlight: false)

                nodeWithResults.union(nodesWithOutdatedResults).forEach({ $0.invalidateText() })

                vm.positions = Array(positions)
                vm.pageHeight = Double(self.frame.size.height ?? 0.0)
            }
        }
    }

    private func highlightCurrentSearchResult(for position: UInt, scrollingToHighlight: Bool = true) {
        guard let searchResults = searchResults else { return }

        var offset = Int(position)
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

            searchResults.map({ $0.element }).forEach({ $0.currentSearchHightlight = nil })
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
