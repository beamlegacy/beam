//
//  NoteEditFocusedState.swift
//  Beam
//
//  Created by Remi Santos on 03/08/2021.
//

import Foundation

struct NoteEditFocusedState {
    var elementId: UUID
    var cursorPosition: Int
    var selectedRange: Range<Int>
    var isReference: Bool = false
    var nodeSelectionState: NodeSelectionState?
    var highlight: Bool = false
    var unfold: Bool = false
}

class NoteEditFocusedStateStorage: ObservableObject {

    private var notesFocusedElementInfos = [UUID: NoteEditFocusedState]()

    @Published var currentFocusedState: NoteEditFocusedState?

    func getSavedNoteFocusedState(noteId: UUID) -> NoteEditFocusedState? {
        notesFocusedElementInfos[noteId]
    }

    func saveNoteFocusedState(noteId: UUID,
                              focusedElement: UUID,
                              cursorPosition: Int,
                              selectedRange: Range<Int>,
                              isReference: Bool, 
                              nodeSelectionState: NodeSelectionState?) {
        let focused = NoteEditFocusedState(elementId: focusedElement,
                                           cursorPosition: cursorPosition,
                                           selectedRange: selectedRange,
                                           isReference: isReference,
                                           nodeSelectionState: nodeSelectionState)
        notesFocusedElementInfos[noteId] = focused
    }
}
