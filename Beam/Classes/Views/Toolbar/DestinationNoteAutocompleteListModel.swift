//
//  DestinationNoteAutocompleteListModel.swift
//  Beam
//
//  Created by Remi Santos on 11/03/2022.
//

import SwiftUI
import BeamCore
import Combine

extension DestinationNoteAutocompleteList {
    class Model: ObservableObject {
        var data: BeamData?
        var useRecents = true
        var recentsAlwaysShowTodayNote = false
        var searchCardContent = false
        var allowNewCardShortcut = true
        var maxNumberOfResults = 4
        var excludeElements: [UUID] = []
        var modifierFlagsPressed: NSEvent.ModifierFlags?

        var selectedResult: AutocompleteResult? {
            guard let index = selectedIndex, !results.isEmpty, index < results.count else {
                return nil
            }
            return results[index]
        }

        var scrollViewProxy: ScrollViewProxy?
        var disableHoverSelection = false
        @Published var selectedIndex: Int?
        @Published var results: [AutocompleteResult] = []
        @Published var searchText: String = "" {
            didSet {
                updateSearchResults()
            }
        }

        func select(result: AutocompleteResult) {
            selectedIndex = indexFor(result: result)
        }

        /// Moves selectedIndex forward one step. Will loop around when going past bounds.
        /// Will default to first result if selectedIndex is nil
        func selectNext() {
            guard !results.isEmpty else { return }
            if let index = selectedIndex {
                selectedIndex = (index + 1).clampInLoop(0, results.endIndex-1)
            } else {
                selectedIndex = 0
            }
        }

        /// Moves selectedIndex back one step. Will loop around when going past bounds.
        /// Will default to last result if selectedIndex is nil
        func selectPrevious() {
            guard !results.isEmpty else { return }
            if let index = selectedIndex {
                selectedIndex = (index - 1).clampInLoop(0, results.endIndex-1)
            } else {
                selectedIndex = results.endIndex - 1
            }
        }

        /// Takes the currently selectedResult and scroll it into view.
        func scrollToSelectResult() {
            if let result = selectedResult {
                disableHoverSelection = true
                scrollViewProxy?.scrollTo(result.id)

                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(100))) { [weak self] in
                    self?.disableHoverSelection = false
                }
            }
        }

        func handleCursorMovement(_ move: CursorMovement) -> Bool {
            switch move {
            case .down:
                NSCursor.setHiddenUntilMouseMoves(true)
                selectNext()
                scrollToSelectResult()
                return true
            case .up:
                NSCursor.setHiddenUntilMouseMoves(true)
                selectPrevious()
                scrollToSelectResult()
                return true
            default:
                return false
            }
        }

        func isSelected(_ result: AutocompleteResult) -> Bool {
            guard !result.disabled, !results.isEmpty else { return false }
            if let i = selectedIndex {
                return results[i].id == result.id
            } else if result.source == .createNote && modifierFlagsPressed?.contains(.option) == true {
                return true
            }
            return false
        }

        private func indexFor(result: AutocompleteResult) -> Int? {
            guard !results.isEmpty else { return nil }
            for i in results.indices where results[i].id == result.id {
                return i
            }
            return nil
        }

        // swiftlint:disable:next nesting
        enum CardReplacementKeyword: String, CaseIterable {
            case yesterday = "Yesterday"
            case today = "Today"
            case tomorrow = "Tomorrow"
        }

        /// Using the card name of tomorrow ("22 September 2021") get the matching journal date
        /// - Parameter cardName: Card name to check
        /// - Returns: returns date if the card name date ("22 September 2021") matches any replacement dates of the CardReplacementKeywords
        func getCardReplacementKeywordDate(_ cardName: String) -> Date? {
            guard let data = data else {
                return nil
            }

            guard let todayDate = BeamNoteType.todaysJournal.journalDate else { return nil }
            let todayDateName = data.todaysName
            // Return early if card name matches today's date
            if cardName == todayDateName {
                return todayDate
            }

            guard let nextDate = BeamNoteType.nextJournal().journalDate else { return nil }
            let nextDateName = BeamDate.journalNoteTitle(for: nextDate)
            // Return early if card name matches next days date
            if cardName == nextDateName {
                return nextDate
            }

            guard let previousDate = BeamNoteType.previousJournal().journalDate else { return nil }
            let previousDateName = BeamDate.journalNoteTitle(for: previousDate, with: .long)
            // Return true / false for the card name matching previous days date
            if cardName == previousDateName {
                return previousDate
            }
            return nil
        }

        /// Gets the real cardname for cardNames like "Today" "Yesterday" or "Tomorrow"
        /// - Parameter cardName: input name, for example: "Today"
        /// - Returns: the actual card name, for example: "21 September 2021"
        func realNameForCardName(_ cardName: String) -> String {
            guard let data = data else {
                return cardName
            }

            var realCardName = cardName
            CardReplacementKeyword.allCases.forEach { replacement in
                if replacement.rawValue.lowercased().contains(cardName.lowercased()) {
                    switch replacement {
                    case .today:
                        realCardName = data.todaysName
                    case .tomorrow:
                        guard let date = BeamNoteType.nextJournal().journalDate else { break }
                        realCardName = BeamDate.journalNoteTitle(for: date)
                    case .yesterday:
                        guard let date = BeamNoteType.previousJournal().journalDate else { break }
                        realCardName = BeamDate.journalNoteTitle(for: date)
                    }
                }
            }
            return realCardName
        }

        /// Returns date for cardNames such as "Today", "Tomorrow", "Yesterday". Also converts matching string dates "21 September 2021" (Today) to Date
        /// - Parameter cardName: input name, for example: "Today"
        /// - Returns: replacement date
        func getDateForCardReplacementJournalNote(_ cardName: String) -> Date? {
            var journalDate: Date?
            // convert replacement words to Date
            CardReplacementKeyword.allCases.forEach { replacement in
                if replacement.rawValue.lowercased().contains(cardName.lowercased()) {
                    switch replacement {
                    case .today:
                        guard let date = BeamNoteType.todaysJournal.journalDate else { break }
                        journalDate = date
                    case .tomorrow:
                        guard let date = BeamNoteType.nextJournal().journalDate else { break }
                        journalDate = date
                    case .yesterday:
                        guard let date = BeamNoteType.previousJournal().journalDate else { break }
                        journalDate = date
                    }
                }
            }

            if let cardReplacementJournalDate = journalDate {
                return cardReplacementJournalDate
            } else if let date = getCardReplacementKeywordDate(cardName) {
                // if not found try converting a matching date string to Date
                return date
            } else {
                return nil
            }
        }

        private func getAutoCompleteResutsForCardReplacement(_ text: String) -> [AutocompleteResult] {
            var autoCompleteResults = [AutocompleteResult]()

            guard text.count >= 1 else { return autoCompleteResults }

            CardReplacementKeyword.allCases.forEach { replacement in
                if replacement.rawValue.lowercased().starts(with: text.lowercased()) {
                    switch replacement {
                    case .today:
                        autoCompleteResults.append(AutocompleteResult(text: CardReplacementKeyword.today.rawValue,
                                                                      source: .note, completingText: text))
                    case .tomorrow:
                        autoCompleteResults.append(AutocompleteResult(text: CardReplacementKeyword.tomorrow.rawValue,
                                                                      source: .note, completingText: text))
                    case .yesterday:
                        autoCompleteResults.append(AutocompleteResult(text: CardReplacementKeyword.yesterday.rawValue,
                                                                      source: .note, completingText: text))
                    }
                }
            }
            return autoCompleteResults
        }

        private func updateSearchResults() {
            var autocompleteItems: [AutocompleteResult]
            if searchCardContent {
                autocompleteItems = getSearchResultForNoteContent(text: searchText, itemLimit: 6)
            } else {
                autocompleteItems = getSearchResultForNoteTitle(text: searchText, itemLimit: maxNumberOfResults)
            }
            selectedIndex = 0
            results = autocompleteItems
        }

        private func getSearchResultForNoteContent(text: String, itemLimit: Int) -> [AutocompleteResult] {
            var dbResults = [GRDBDatabase.SearchResult]()
            if !text.isEmpty {
                dbResults = GRDBDatabase.shared.search(matchingAnyTokenIn: text, maxResults: itemLimit, includeText: true, excludeElements: excludeElements)
            }
            var results: [AutocompleteResult] = dbResults.compactMap { r in
                let elementId = r.uid
                guard elementId != r.noteId, let text = r.text, !text.isEmpty else { return nil }
                return AutocompleteResult(text: text, source: .note(noteId: r.noteId, elementId: elementId), uuid: elementId)
            }
            if results.isEmpty {
                let placeholderText = text.isEmpty ? "Search for a Block" : "No Results Found"
                results.append(AutocompleteResult(text: placeholderText, source: .note, disabled: true))
            }
            return results
        }

        private func getSearchResultForNoteTitle(text: String, itemLimit: Int) -> [AutocompleteResult] {
            var autocompleteItems: [AutocompleteResult]
            var allowCreateCard = false
            var items = [DocumentStruct]()
            var scores = [UUID: FrecencyNoteRecord]()
            let documentManager = DocumentManager()
            if !text.isEmpty {
                allowCreateCard = true
                items = documentManager.documentsWithTitleMatch(title: text)
                let noteIds = items.map { $0.id }
                scores = GRDBDatabase.shared.getFrecencyScoreValues(noteIds: noteIds, paramKey: AutocompleteManager.noteFrecencyParamKey)
            } else if useRecents {
                //When query is empty, we get top N frecencies' noteIds
                //and fetch corresponding notes (avoids fetching all the notes)
                scores = GRDBDatabase.shared.getTopNoteFrecencies(limit: itemLimit, paramKey: AutocompleteManager.noteFrecencyParamKey)
                items = documentManager.loadDocumentsById(ids: Array(scores.keys))
                if recentsAlwaysShowTodayNote, let todayNote = data?.todaysNote.documentStruct {
                    if let index = items.firstIndex(where: { $0.id == todayNote.id }) {
                        items.remove(at: index)
                    } else if !items.isEmpty {
                        items.removeLast()
                    }
                    items.insert(todayNote, at: 0)
                }
            }
            let cleanedItems: [DocumentStruct] = items.compactMap { doc in
                if text.containsSymbol || text.containsWhitespace {
                    return doc
                }
                let slicedItem = doc.title.components(separatedBy: .whitespaces.union(.punctuationCharacters))
                let containsTextPrefixedSlice = slicedItem.contains { slice in
                    slice.lowercased().starts(with: text.lowercased())
                }
                return containsTextPrefixedSlice ? doc : nil
            }

            let itemsSlice = cleanedItems.map {
                AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), completingText: searchText, uuid: $0.id, score: scores[$0.id]?.frecencySortScore)
            }
                .sorted(by: >)
                .prefix(itemLimit)
            autocompleteItems = Array(itemsSlice)
            let cardReplacementResults = getAutoCompleteResutsForCardReplacement(text)
            if !cardReplacementResults.isEmpty {
                autocompleteItems.append(contentsOf: cardReplacementResults)
                autocompleteItems = Array(autocompleteItems.prefix(itemLimit))
            }
            allowCreateCard = allowCreateCard
            && !items.contains(where: { $0.title.lowercased() == text.lowercased() })
            if allowCreateCard && !text.isEmpty {
                let createItem = AutocompleteResult(text: text, source: .createNote, information: loc("New Note"),
                                                    shortcut: Shortcut(modifiers: [.option], keys: [.enter]))
                if autocompleteItems.count >= itemLimit {
                    autocompleteItems[autocompleteItems.count - 1] = createItem
                } else {
                    autocompleteItems.append(createItem)
                }
            }
            return autocompleteItems
        }
    }
}
