//
//  DestinationNoteAutocompleteList.swift
//  Beam
//
//  Created by Remi Santos on 09/03/2021.
//

import SwiftUI
import BeamCore
import Combine

struct DestinationNoteAutocompleteList: View {

    enum DesignVariation {
        case TextEditor(leadingPadding: CGFloat)
        case SearchField
    }

    @ObservedObject var model = Model()
    var variation: DesignVariation = .SearchField
    var allowScroll: Bool = false
    internal var onSelectAutocompleteResult: (() -> Void)?

    private let itemHeight: CGFloat = 32
    private let customColorPalette = AutocompleteItemColorPalette(
        textColor: BeamColor.Beam,
        informationTextColor: BeamColor.LightStoneGray,
        selectedBackgroundColor: BeamColor.NotePicker.selected,
        touchdownBackgroundColor: BeamColor.NotePicker.active)

    private let customTextEditorColorPalette = AutocompleteItemColorPalette(
        textColor: BeamColor.Beam,
        informationTextColor: BeamColor.LightStoneGray,
        selectedBackgroundColor: BeamColor.NotePicker.selected,
        touchdownBackgroundColor: BeamColor.NotePicker.active)

    private var colorPalette: AutocompleteItemColorPalette {
        guard !model.searchCardContent else { return AutocompleteItem.defaultColorPalette }
        if case .TextEditor = variation { return customTextEditorColorPalette}
        return customColorPalette
    }

    private var additionLeadingPadding: CGFloat {
        guard case .TextEditor(let leadingPadding) = variation else { return 0 }
        return leadingPadding
    }

    private var alwaysHighlightCompletingText: Bool {
        if case .TextEditor = variation { return false }
        return true
    }

    var body: some View {
        Group {
            if allowScroll {
                ScrollView {
                    ScrollViewReader { proxy in
                        list.onAppear {
                            model.scrollViewProxy = proxy
                        }
                    }
                }
            } else {
                list
            }
        }
    }

    var list: some View {
        VStack(spacing: 0) {
            ForEach(model.results, id: \.id) { i in
                return AutocompleteItem(item: i, selected: model.isSelected(i), disabled: i.disabled, displayIcon: false,
                                        alwaysHighlightCompletingText: alwaysHighlightCompletingText,
                                        allowNewCardShortcut: model.allowNewCardShortcut, colorPalette: colorPalette,
                                        additionalLeadingPadding: additionLeadingPadding)
                    .if(model.searchCardContent) {
                        $0.frame(minHeight: itemHeight).fixedSize(horizontal: false, vertical: true)
                    }
                    .if(!model.searchCardContent) {
                        $0.frame(height: itemHeight)
                    }
                    .id(i.id)
                    .transition(.identity)
                    .animation(nil)
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            model.select(result: i)
                            onSelectAutocompleteResult?()
                        }
                    )
                    .onHover { hovering in
                        if hovering && !model.disableHoverSelection {
                            model.select(result: i)
                        }
                    }
            }
        }
        .onHover { hovering in
            if !hovering && !model.disableHoverSelection {
                model.selectedIndex = 0
            }
        }
        .frame(maxWidth: .infinity)
    }

}

extension DestinationNoteAutocompleteList {
    func onSelectAutocompleteResult(perform action: @escaping () -> Void ) -> Self {
         var copy = self
         copy.onSelectAutocompleteResult = action
         return copy
     }
}

extension DestinationNoteAutocompleteList {
    class Model: ObservableObject {
        var data: BeamData?
        var useRecents = true
        var searchCardContent = false
        var allowNewCardShortcut = true
        var excludeElements: [UUID] = []
        var modifierFlagsPressed: NSEvent.ModifierFlags?

        var selectedResult: AutocompleteResult? {
            guard let index = selectedIndex, index < results.count else {
                return nil
            }
            return results[index]
        }

        fileprivate var scrollViewProxy: ScrollViewProxy?
        fileprivate var disableHoverSelection = false
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

        func handleCursorMovement(_ move: CursorMovement) -> Bool {
            switch move {
            case .down, .up:
                NSCursor.setHiddenUntilMouseMoves(true)
                var newIndex = self.selectedIndex ?? -1
                newIndex += (move == .up ? -1 : 1)
                newIndex = newIndex.clampInLoop(0, results.count - 1)
                selectedIndex = newIndex
                if let item = selectedResult {
                    disableHoverSelection = true
                    scrollViewProxy?.scrollTo(item.id)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(100))) { [weak self] in
                        guard self?.selectedIndex == newIndex else { return }
                        self?.disableHoverSelection = false
                    }
                }
                return true
            default:
                return false
            }
        }

        func isSelected(_ result: AutocompleteResult) -> Bool {
            guard !result.disabled else { return false }
            if let i = selectedIndex {
                return results[i].id == result.id
            } else if result.source == .createCard && modifierFlagsPressed?.contains(.command) == true {
                return true
            }
            return false
        }

        private func indexFor(result: AutocompleteResult) -> Int? {
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

            CardReplacementKeyword.allCases.forEach { replacement in
                if replacement.rawValue.lowercased().contains(text.lowercased()) {
                    switch replacement {
                    case .today:
                        autoCompleteResults.append(AutocompleteResult(text: CardReplacementKeyword.today.rawValue,
                                                                      source: .autocomplete))
                    case .tomorrow:
                        autoCompleteResults.append(AutocompleteResult(text: CardReplacementKeyword.tomorrow.rawValue,
                                                                      source: .autocomplete))
                    case .yesterday:
                        autoCompleteResults.append(AutocompleteResult(text: CardReplacementKeyword.yesterday.rawValue,
                                                                      source: .autocomplete))
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
                autocompleteItems = getSearchResultForNoteTitle(text: searchText, itemLimit: 4)
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
            }
            let itemsSlice = items.map {
                AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), completingText: searchText, uuid: $0.id, score: scores[$0.id]?.frecencySortScore)
            }
                .sorted(by: >)
                .prefix(itemLimit)
            autocompleteItems = Array(itemsSlice)
            let cardReplacementResults = getAutoCompleteResutsForCardReplacement(text)
            if !cardReplacementResults.isEmpty {
                autocompleteItems.insert(contentsOf: cardReplacementResults, at: 0)
                autocompleteItems = Array(autocompleteItems.prefix(itemLimit))
            }
            allowCreateCard = allowCreateCard
                && !items.contains(where: { $0.title.lowercased() == text.lowercased() })
            if allowCreateCard && !text.isEmpty {
                let createItem = AutocompleteResult(text: text, source: .createCard, information: "New Note")
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

struct DestinationNoteAutocompleteList_Previews: PreviewProvider {
    static var elements = [
        AutocompleteResult(text: "Result", source: .autocomplete),
        AutocompleteResult(text: "Result 2", source: .autocomplete),
        AutocompleteResult(text: "Result third", source: .autocomplete)]
    static let model = DestinationNoteAutocompleteList.Model()
    static var previews: some View {
        model.data = BeamData()
        model.searchText = "Resul"
        model.results = elements
        return DestinationNoteAutocompleteList(model: model)
    }
}
