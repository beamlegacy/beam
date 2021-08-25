//
//  DestinationNoteAutocompleteList.swift
//  Beam
//
//  Created by Remi Santos on 09/03/2021.
//

import SwiftUI
import BeamCore

struct DestinationNoteAutocompleteList: View {

    enum DesignVariation {
        case TextEditor
        case SearchField
    }

    @ObservedObject var model = Model()
    var variation: DesignVariation = .SearchField
    internal var onSelectAutocompleteResult: (() -> Void)?

    private let itemHeight: CGFloat = 32
    private let customColorPalette = AutocompleteItemColorPalette(
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
        return variation == .TextEditor ? customTextEditorColorPalette : customColorPalette
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.results) { i in
                return AutocompleteItem(item: i, selected: model.isSelected(i), displayIcon: false,
                                        alwaysHighlightCompletingText: variation != .TextEditor,
                                        allowCmdEnter: model.allowCmdEnter, colorPalette: colorPalette)
                    .if(model.searchCardContent) {
                        $0.frame(minHeight: itemHeight).fixedSize(horizontal: false, vertical: true)
                    }
                    .if(!model.searchCardContent) {
                        $0.frame(height: itemHeight)
                    }
                    .transition(.identity)
                    .animation(nil)
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            model.select(result: i)
                            onSelectAutocompleteResult?()
                        }
                    )
                    .onHover { hovering in
                        if hovering {
                            model.select(result: i)
                        }
                    }
            }
        }
        .onHover { hovering in
            if !hovering {
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
        var allowCmdEnter = true
        var modifierFlagsPressed: NSEvent.ModifierFlags?

        var selectedResult: AutocompleteResult? {
            guard let index = selectedIndex, index < results.count else {
                return nil
            }
            return results[index]
        }

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
                return true
            default:
                return false
            }
        }

        func isSelected(_ result: AutocompleteResult) -> Bool {
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

        let todaysCardReplacementName = "Today"
        func realNameForCardName(_ cardName: String) -> String {
            guard let data = data, cardName.lowercased() == todaysCardReplacementName.lowercased() else {
                return cardName
            }
            return data.todaysName
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
            var dbResults: [GRDBDatabase.SearchResult]
            if text.isEmpty {
                dbResults = GRDBDatabase.shared.search(allWithMaxResults: itemLimit, includeText: true)
            } else {
                dbResults = GRDBDatabase.shared.search(matchingAnyTokenIn: text, maxResults: itemLimit, includeText: true)
            }
            return dbResults.map { r in
                AutocompleteResult(text: r.text ?? r.title, source: .note(noteId: r.noteId, elementId: r.uid), uuid: r.uid)
            }
        }

        private func getSearchResultForNoteTitle(text: String, itemLimit: Int) -> [AutocompleteResult] {
            guard let data = data else { return [] }
            var autocompleteItems: [AutocompleteResult]
            var allowCreateCard = false
            var items = [DocumentStruct]()
            if !text.isEmpty {
                allowCreateCard = true
                items = data.documentManager.documentsWithLimitTitleMatch(title: text, limit: itemLimit)
            } else if useRecents {
                items = data.documentManager.loadAllWithLimit(itemLimit)
            }
            if (todaysCardReplacementName.lowercased().contains(text.lowercased())
                    && !items.contains(where: { $0.title == data.todaysName })) {
                let todaysNotes = data.documentManager.documentsWithLimitTitleMatch(title: data.todaysName, limit: 1)
                items.insert(contentsOf: todaysNotes, at: 0)
                items = Array(items.prefix(itemLimit))
            }
            allowCreateCard = allowCreateCard
                && !items.contains(where: { $0.title.lowercased() == text.lowercased() })
            autocompleteItems = items.map {
                AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), completingText: searchText, uuid: $0.id)
            }
            if allowCreateCard && !text.isEmpty {
                let createItem = AutocompleteResult(text: text, source: .createCard, information: "New Card")
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
