//
//  DestinationNoteAutocompleteList.swift
//  Beam
//
//  Created by Remi Santos on 09/03/2021.
//

import SwiftUI
import BeamCore

struct DestinationNoteAutocompleteList: View {

    @ObservedObject var model: Model

    internal var onSelectAutocompleteResult: (() -> Void)?
    private let itemHeight: CGFloat = 32
    private let colorPalette = AutocompleteItemColorPalette(selectedBackgroundColor: BeamColor.NotePicker.selected.nsColor, touchdownBackgroundColor: BeamColor.NotePicker.active.nsColor)
    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.results) { i in
                return AutocompleteItem(item: i, selected: model.isSelected(i), displayIcon: false, colorPalette: colorPalette)
                    .frame(height: itemHeight)
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
        .animation(nil)
        .onHover { hovering in
            if !hovering {
                model.selectedIndex = nil
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
                var newIndex = selectedIndex ?? -1
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

        private let todaysCardReplacementName = "Today"
        func displayNameForCardName(_ cardName: String) -> String {
            return cardName == data?.todaysName ? todaysCardReplacementName : cardName
        }
        func realNameForCardName(_ cardName: String) -> String {
            guard let data = data, cardName.lowercased() == todaysCardReplacementName.lowercased() else {
                return cardName
            }
            return data.todaysName
        }

        private func updateSearchResults() {
            guard let data = data else { return }
            var allowCreateCard = false
            var items = [DocumentStruct]()
            let itemLimit = 4
            if !searchText.isEmpty {
                allowCreateCard = true
                items = data.documentManager.documentsWithLimitTitleMatch(title: searchText, limit: itemLimit)
            } else if useRecents {
                items = data.documentManager.loadAllDocumentsWithLimit(itemLimit)
            }
            if (todaysCardReplacementName.lowercased().contains(searchText.lowercased()) && !items.contains(where: { $0.title == data.todaysName })) {
                let todaysNotes = data.documentManager.documentsWithLimitTitleMatch(title: data.todaysName, limit: 1)
                items.insert(contentsOf: todaysNotes, at: 0)
                items = Array(items.prefix(itemLimit))
            }
            allowCreateCard = allowCreateCard && !items.contains(where: { $0.title.lowercased() == searchText.lowercased() })
            selectedIndex = 0
            var autocompleteItems = items.map { doc -> AutocompleteResult in
                var title = doc.title
                if let note = BeamNote.getFetchedNote(title) {
                    title = note.title
                }
                return AutocompleteResult(text: displayNameForCardName(title), source: .note, uuid: doc.id)
            }
            if allowCreateCard && !searchText.isEmpty {
                let createItem = AutocompleteResult(text: searchText, source: .createCard, information: "New Card")
                if autocompleteItems.count >= itemLimit {
                    autocompleteItems[autocompleteItems.count - 1] = createItem
                } else {
                    autocompleteItems.append(createItem)
                }
            }
            results = autocompleteItems
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
