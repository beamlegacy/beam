//
//  DestinationNodePicker.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/01/2021.
//

import AppKit
import SwiftUI
import Foundation
import BeamCore

struct DestinationNotePicker: View {
    let tab: BrowserTab
    @EnvironmentObject var state: BeamState
    @State var isHovering = false
    @State var isMouseDown = false

    @State private var selectedResultIndex: Int?
    @State private var listResults = [AutocompleteResult]()

    private var enableAnimations: Bool {
        !state.windowIsResizing
    }
    private let boxHeight: CGFloat = 32
    private let maxBoxWidth: CGFloat = 230
    private let todaysCardReplacementName = "Today"
    private var title: String {
        displayNameForCardName(state.destinationCardName)
    }
    private var placeholder: String {
        let currentNote = displayNameForCardName(tab.note.title)
        return !currentNote.isEmpty ? currentNote : "Destination Card"
    }
    private func displayNameForCardName(_ cardName: String) -> String {
        return cardName == state.data.todaysName ? todaysCardReplacementName : cardName
    }

    private var isEditing: Bool {
        state.destinationCardIsFocused
    }

    private func setIsEditing(_ editing: Bool) {
        state.destinationCardIsFocused = editing
    }

    private var animation: Animation? {
        enableAnimations ? .easeInOut(duration: 0.3) : nil
    }

    var body: some View {

        let isEditingBinding = Binding<Bool>(get: {
            isEditing
        }, set: {
            setIsEditing($0)
        })

        let textBinding = Binding<String>(get: {
            title
        }, set: {
            state.destinationCardName = $0
        })
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.destinationNoteBorderColor).opacity(isMouseDown ? 1.0 : 0.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(.destinationNoteBorderColor))
                        .opacity(isEditing || isHovering ? 1.0 : 0.0)
                )
                .frame(minWidth: isEditing ? 230 : 0, maxHeight: boxHeight)
            ZStack(alignment: .topLeading) {
                Text(title)
                    .font(.system(size: 12))
                    .padding(8)
                    .frame(maxWidth: maxBoxWidth, alignment: .leading)
                    .frame(height: boxHeight)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(.white)
                    .colorMultiply(isHovering || isMouseDown ? Color(.destinationNoteActiveTextColor) : Color(.destinationNoteTextColor))
                    .animation(animation)
                    .opacity(isEditing ? 0.0 : 1.0)
                    .accessibility(identifier: "DestinationNoteTitle")
                VStack(spacing: 2) {
                    HStack {
                        BeamTextField(
                            text: textBinding,
                            isEditing: isEditingBinding,
                            placeholder: placeholder,
                            font: .systemFont(ofSize: 12),
                            textColor: isHovering || isMouseDown ? .destinationNoteActiveTextColor : .destinationNoteTextColor,
                            placeholderColor: NSColor.omniboxPlaceholderTextColor,
                            selectedRanges: state.destinationCardNameSelectedRange
                        ) { newName in
                            Logger.shared.logInfo("[DestinationNotePicker] Searching '\(newName)'", category: .ui)
                            state.destinationCardNameSelectedRange = nil
                            updateSearchResults()
                        } onCommit: { modifierFlags in
                            selectedCurrentAutocompleteResult(withCommand: modifierFlags?.contains(.command) ?? false)
                        } onEscape: {
                            cancelSearch()
                        } onCursorMovement: { move -> Bool in
                            return handleCursorMovement(move)
                        } onStartEditing: {
                            Logger.shared.logInfo("[DestinationNotePicker] Start Editing", category: .ui)
                            if tab.note.isTodaysNote {
                                state.destinationCardName = ""
                                state.destinationCardNameSelectedRange = nil
                            } else {
                                state.destinationCardNameSelectedRange = [state.destinationCardName.wholeRange]
                            }
                            updateSearchResults()
                        } onStopEditing: {
                            cancelSearch()
                        }
                    }
                    .padding(8)
                    .accessibility(addTraits: .isSearchField)
                    .accessibility(identifier: "DestinationNoteSearchField")
                    .onAppear(perform: {
                        state.destinationCardName = tab.note.title
                    })
                    .animation(animation)
                    .opacity(isEditing ? 1.0 : 0.01)
                    HStack {
                        if isEditing && listResults.count > 0 {
                            DestinationNoteAutocompleteList(selectedIndex: $selectedResultIndex, elements: $listResults)
                                .onSelectAutocompleteResult {
                                    selectedCurrentAutocompleteResult()
                                }
                                .frame(width: maxBoxWidth)
                        }
                    }
                    .animation(.easeInOut(duration: 0.1))
                }
                .animation(nil)
                .frame(maxWidth: maxBoxWidth)
            }
        }
        .frame(minWidth: isEditing ? maxBoxWidth : 0)
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTouchDown { touching in
            isMouseDown = touching
        }
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                setIsEditing(true)
            }
        )
    }

    func handleCursorMovement(_ move: CursorMovement) -> Bool {
        switch move {
        case .down, .up:
            NSCursor.setHiddenUntilMouseMoves(true)
            var newIndex = selectedResultIndex ?? -1
            newIndex += (move == .up ? -1 : 1)
            newIndex = newIndex.clampInLoop(0, listResults.count - 1)
            selectedResultIndex = newIndex
            return true
        default:
            return false
        }
    }

    func updateSearchResults() {
        Logger.shared.logInfo("Update Destination Picker Results for query \(state.destinationCardName)", category: .ui)
        var allowCreateCard = false
        var items = [DocumentStruct]()
        let queryText = state.destinationCardName
        let itemLimit = 4
        if queryText.isEmpty {
            items = state.data.documentManager.loadAllDocumentsWithLimit(itemLimit)
        } else {
            allowCreateCard = true
            items = state.data.documentManager.documentsWithLimitTitleMatch(title: queryText, limit: itemLimit)
        }
        if (todaysCardReplacementName.lowercased().contains(queryText.lowercased()) && !items.contains(where: { $0.title == state.data.todaysName })) {
            let todaysNotes = state.data.documentManager.documentsWithLimitTitleMatch(title: state.data.todaysName, limit: 1)
            items.insert(contentsOf: todaysNotes, at: 0)
            items = Array(items.prefix(itemLimit))
        }
        allowCreateCard = allowCreateCard && !items.contains(where: { $0.title.lowercased() == queryText.lowercased() })
        selectedResultIndex = 0
        var autocompleteItems = items.map { AutocompleteResult(text: displayNameForCardName($0.title), source: .note, uuid: $0.id) }
        if allowCreateCard {
            let createItem = AutocompleteResult(text: queryText, source: .createCard, information: "New Card")
            if autocompleteItems.count >= itemLimit {
                autocompleteItems[autocompleteItems.count - 1] = createItem
            } else {
                autocompleteItems.append(createItem)
            }
        }
        listResults = autocompleteItems
    }

    func changeDestinationCard(to cardName: String) {
        let cardName = cardName.lowercased() == todaysCardReplacementName.lowercased() ? state.data.todaysName : cardName
        state.destinationCardName = cardName
        let note = BeamNote.fetchOrCreate(state.data.documentManager, title: cardName)
        tab.setDestinationNote(note, rootElement: note)
    }

    func createNote(named name: String) {
        _ = state.createNoteForQuery(name)
    }

    func selectedCurrentAutocompleteResult(withCommand: Bool = false) {
        let noteName: String
        if withCommand {
            noteName = state.destinationCardName
            createNote(named: noteName)
        } else {
            guard let selectedResultIndex = selectedResultIndex, selectedResultIndex < listResults.count else {
                return
            }
            let result = listResults[selectedResultIndex]
            if result.source == .createCard {
                createNote(named: result.text)
            }
            noteName = result.text
        }
        changeDestinationCard(to: noteName)
        DispatchQueue.main.async {
            cancelSearch()
        }
    }

    func cancelSearch() {
        state.resetDestinationCard()
        listResults = []
    }
}

struct DestinationNotePicker_Previews: PreviewProvider {
    static var previews: some View {
        let state = BeamState()
        let tab = BrowserTab(state: state, originalQuery: "original query", note: BeamNote(title: "Query text"))
        let focusedState = BeamState()
        focusedState.destinationCardIsFocused = true
        let itemHeight: CGFloat = 32.0
        return
            VStack {
                DestinationNotePicker(tab: tab).environmentObject(state)
                    .frame(height: itemHeight)
                DestinationNotePicker(tab: tab, isHovering: true).environmentObject(state)
                    .frame(height: itemHeight)
                DestinationNotePicker(tab: tab, isMouseDown: true).environmentObject(state)
                    .frame(height: itemHeight)
                DestinationNotePicker(tab: tab).environmentObject(focusedState)
                    .frame(height: itemHeight)
            }
            .padding()
            .background(Color.white)
    }
}
