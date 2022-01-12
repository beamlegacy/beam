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
    @Environment(\.isMainWindow) private var isMainWindow

    let tab: BrowserTab
    @EnvironmentObject var state: BeamState
    @State var isHovering = false
    @State var isMouseDown = false

    @State private var _internalDisableAnimation = false
    private var enableAnimations: Bool {
        !_internalDisableAnimation && !state.windowIsResizing
    }
    private let boxHeight: CGFloat = 32
    private let maxBoxWidth: CGFloat = 230
    private var title: String {
        guard !isEditing else {
            return state.destinationCardName
        }
        if let note = tab.noteController.note {
            if let date = note.type.journalDate {
                return BeamDate.journalNoteTitle(for: date, with: .medium)
            } else {
                return state.destinationCardName
            }
        }
        return BeamDate.journalNoteTitle(for: BeamDate.now, with: .medium)
    }
    private var placeholder: String {
        let currentNote = tab.noteController.noteOrDefault.title
        return !currentNote.isEmpty ? currentNote : "Destination Note"
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

    private var textColor: BeamColor {
        guard isMainWindow else { return BeamColor.AlphaGray }
        return isHovering || isMouseDown || isEditing ? BeamColor.Generic.text : BeamColor.LightStoneGray
    }

    @State private var autocompleteModel = DestinationNoteAutocompleteList.Model()

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
            RoundedRectangle(cornerRadius: 6)
                .fill(BeamColor.NotePicker.border.swiftUI.opacity(isMouseDown ? 1.0 : 0.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(BeamColor.NotePicker.border.swiftUI)
                        .opacity(isEditing || isMouseDown ? 1.0 : 0.0)
                )
                .frame(minWidth: isEditing ? 230 : 0, maxHeight: boxHeight)
            ZStack(alignment: .topLeading) {
                Text(title)
                    .font(.system(size: 12))
                    .padding(BeamSpacing._80)
                    .frame(maxWidth: maxBoxWidth, alignment: .leading)
                    .frame(height: boxHeight)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(.white)
                    .colorMultiply(textColor.swiftUI)
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
                            textColor: textColor.nsColor,
                            placeholderColor: BeamColor.Generic.placeholder.nsColor,
                            selectedRange: state.destinationCardNameSelectedRange
                        ) { newName in
                            Logger.shared.logInfo("[DestinationNotePicker] Searching '\(newName)'", category: .ui)
                            state.destinationCardNameSelectedRange = nil
                            updateSearchResults()
                        } onCommit: { modifierFlags in
                            selectedCurrentAutocompleteResult(withCommand: modifierFlags?.contains(.command) ?? false)
                        } onEscape: {
                            cancelSearch()
                        } onCursorMovement: { move -> Bool in
                            autocompleteModel.handleCursorMovement(move)
                        } onStartEditing: {
                            Logger.shared.logInfo("[DestinationNotePicker] Start Editing", category: .ui)
                            if tab.noteController.note == nil {
                                state.destinationCardName = ""
                                state.destinationCardNameSelectedRange = nil
                            } else {
                                state.destinationCardNameSelectedRange = state.destinationCardName.wholeRange
                            }
                            updateSearchResults()
                        } onStopEditing: {
                            cancelSearch()
                        }
                        .frame(minHeight: isEditing ? 16 : 0)
                    }
                    .padding(BeamSpacing._80)
                    .accessibility(addTraits: .isSearchField)
                    .accessibility(identifier: "DestinationNoteSearchField")
                    .onAppear(perform: {
                        autocompleteModel.data = state.data
                        _internalDisableAnimation = true
                        state.destinationCardName = tab.noteController.noteOrDefault.title
                        autocompleteModel.searchText = tab.noteController.note != nil ? state.destinationCardName : ""
                        DispatchQueue.main.async {
                            _internalDisableAnimation = false
                        }
                    })
                    .animation(animation)
                    .opacity(isEditing ? 1.0 : 0.01)
                    if isEditing {
                        DestinationNotePickerBackground(isEditing: true, enableAnimations: enableAnimations) {
                            DestinationNoteAutocompleteList(model: autocompleteModel)
                                .onSelectAutocompleteResult {
                                    selectedCurrentAutocompleteResult()
                                }
                        }
                        .frame(width: maxBoxWidth, alignment: .top)
                        .animation(animation)
                        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.15)))
                    }
                }
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
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            setIsEditing(true)
        })
        .transition(.identity)
        .id(tab.id)
    }

    func updateSearchResults() {
        Logger.shared.logInfo("Update Destination Picker Results for query \(state.destinationCardName)", category: .ui)
        autocompleteModel.searchText = state.destinationCardName
    }

    func changeDestinationCard(to cardName: String, note: BeamNote?) {
        let cardName = autocompleteModel.realNameForCardName(cardName)
        state.destinationCardName = cardName
        if let finalNote = note ?? BeamNote.fetch(title: cardName) {
            tab.setDestinationNote(finalNote, rootElement: finalNote)
        }
    }

    @discardableResult
    func createNote(named name: String) -> BeamNote {
        let note = BeamNote.fetchOrCreate(title: name)
        note.save()
        return note
    }

    @discardableResult
    func createJournalNote(date: Date) -> BeamNote {
        let note = BeamNote.fetchOrCreateJournalNote(date: date)
        note.save()
        return note
    }

    func selectedCurrentAutocompleteResult(withCommand: Bool = false) {
        let noteName: String
        var note: BeamNote?
        if withCommand {
            noteName = state.destinationCardName
            note = createNote(named: noteName)
        } else {
            guard let result = autocompleteModel.selectedResult else {
                return
            }
            let finalCardName = autocompleteModel.realNameForCardName(result.text)
            if result.source == .createCard {
                note = createNote(named: result.text)
            } else if result.source == .autocomplete && result.text != finalCardName,
                      let date = autocompleteModel.getDateForCardReplacementJournalNote(result.text) {
                note = createJournalNote(date: date)
            }
            noteName = finalCardName
        }
        changeDestinationCard(to: noteName, note: note)
        DispatchQueue.main.async {
            cancelSearch()
        }
    }

    func cancelSearch() {
        state.resetDestinationCard()
    }
}

struct DestinationNotePicker_Previews: PreviewProvider {
    static var previews: some View {
        let state = BeamState()
        let origin = BrowsingTreeOrigin.searchBar(query: "original query")
        let tab = BrowserTab(state: state, browsingTreeOrigin: origin, originMode: .today, note: BeamNote(title: "Query text"))
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
