//
//  OmniBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import AppKit

struct OmniBar: View {
    @EnvironmentObject var state: BeamState
    var canSearch: Bool {
        return !state.searchQuery.isEmpty || !state.isEditingOmniBarTitle
    }
    
    var body: some View {
        HStack {
            Chevrons()
            
            if state.mode == .note {
                HStack {
                    GlobalNoteTitle(note: state.currentNote!)
                    
                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }
                    .buttonStyle(RoundRectButtonStyle())
                }.padding(.leading, 9)
            } else {
                BeamSearchBox(isEditing: $state.isEditingOmniBarTitle)
            }
            
            Button(action: toggleMode) {
                Symbol(name: state.mode == .web ? "note.text" : "network")
            }.buttonStyle(RoundRectButtonStyle()).disabled(state.tabs.isEmpty)
        }
    }
    
    func resetAutoCompleteSelection() {
        state.resetAutocompleteSelection()
    }
    
    func startNewSearch() {
        state.startNewSearch()
    }
    
    func toggleMode() {
        if state.mode == .web {
            guard let tab = state.currentTab else { return }
            if let note = tab.note {
                state.currentNote = note
            }
            if let note = state.currentNote {
                state.navigateToNote(note)
            } else {
                state.navigateToJournal()
            }
            state.resetQuery()
        } else {
            state.mode = .web
        }
    }
}
