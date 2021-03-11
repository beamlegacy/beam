//
//  DestinationNodePicker.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/01/2021.
//

import AppKit
import SwiftUI
import Foundation

struct DestinationNotePicker: View {
    var tab: BrowserTab
    @EnvironmentObject var state: BeamState
    @State var isHovering = false
    @State var isMouseDown = false

    @State var selectedResultIndex: Int?
    @State var listResults = [AutocompleteResult]()

    private let boxHeight: CGFloat = 32
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
                .fill(isMouseDown ? Color(.destinationNoteBorderColor) : Color(.transparent))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isEditing || isHovering ? Color(.destinationNoteBorderColor) : Color(.transparent))
                )
                .frame(maxHeight: boxHeight)
            ZStack(alignment: .top) {
                VStack(spacing: 2) {
                    HStack {
                        BeamTextField(
                            text: textBinding,
                            isEditing: isEditingBinding,
                            placeholder: placeholder,
                            font: .systemFont(ofSize: 12),
                            textColor: .destinationNoteActiveTextColor,
                            placeholderColor: NSColor.omniboxPlaceholderTextColor,
                            selectedRanges: state.destinationCardNameSelectedRange
                        ) { newName in
                            Logger.shared.logInfo("[DestinationNotePicker] Searching '\(newName)'", category: .ui)
                            state.destinationCardNameSelectedRange = nil
                            updateSearchResults()
                        } onCommit: {
                            selectedCurrentAutocompleteResult()
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
                    .accessibility(addTraits: .isSearchField)
                    .accessibility(identifier: "DestinationNoteSearchField")
                    .padding(8)
                    .onAppear(perform: {
                        state.destinationCardName = tab.note.title
                    })
                    if isEditing && listResults.count > 0 {
                        DestinationNoteAutocompleteList(selectedIndex: $selectedResultIndex, elements: $listResults)
                            .onSelectAutocompleteResult {
                                selectedCurrentAutocompleteResult()
                            }
                            .frame(minWidth: 230)
                    }
                }
                .opacity(!isEditing ? 0.01 : 1.0)
                .frame(maxWidth: isEditing ? .infinity : 0.0)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(.white)
                    .colorMultiply(isHovering || isMouseDown ? Color(.destinationNoteActiveTextColor) : Color(.destinationNoteTextColor))
                    .animation(.easeInOut)
                    .padding(8)
                    .frame(height: boxHeight)
                    .onTapGesture {
                        setIsEditing(true)
                    }
                    .opacity(isEditing ? 0 : 1.0)
                    .accessibility(identifier: "DestinationNoteTitle")
            }
        }
        .frame(minWidth: isEditing ? 230 : 0)
        .fixedSize(horizontal: true, vertical: false)
        .onTouchDown { touching in
            isMouseDown = touching
        }
        .onHover { hovering in
            isHovering = hovering
        }
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
        var items = state.destinationCardName.isEmpty ? state.data.documentManager.loadAllDocumentsWithLimit(4) : state.data.documentManager.documentsWithLimitTitleMatch(title: state.destinationCardName, limit: 4)
        if (todaysCardReplacementName.lowercased().contains(state.destinationCardName.lowercased())  && !items.contains(where: { $0.title == state.data.todaysName })) {
            let todaysNotes = state.data.documentManager.documentsWithLimitTitleMatch(title: state.data.todaysName, limit: 1)
            items.insert(contentsOf: todaysNotes, at: 0)
        }
        selectedResultIndex = 0
        listResults = items.map { AutocompleteResult(text: displayNameForCardName($0.title), source: .note, uuid: $0.id) }
    }

    func changeDestinationCard(to cardName: String) {
        let cardName = cardName.lowercased() == todaysCardReplacementName.lowercased() ? state.data.todaysName : cardName
        state.destinationCardName = cardName
        let note = BeamNote.fetchOrCreate(state.data.documentManager, title: cardName)
        tab.setDestinationNote(note, rootElement: note)
    }

    func selectedCurrentAutocompleteResult() {
        guard let selectedResultIndex = selectedResultIndex, selectedResultIndex < listResults.count else {
            return
        }
        let result = listResults[selectedResultIndex]
        changeDestinationCard(to: result.text)
        cancelSearch()
    }

    func cancelSearch() {
        state.resetDestinationCard()
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
