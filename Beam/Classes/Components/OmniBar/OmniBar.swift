//
//  OmniBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import Combine
import AppKit

struct OmniBar: View {
    @EnvironmentObject var state: BeamState
    @State var title = ""

    var canSearch: Bool {
        return !state.searchQuery.isEmpty || !state.isEditingOmniBarTitle
    }

    var body: some View {
        HStack {
            Chevrons()

            if state.mode == .note {
                HStack {
                    GlobalNoteTitle(
                        title: $title,
                        note: state.currentNote!
                    ).onReceive(state.$currentNote, perform: { value in
                        guard let currentNote = value else { return }
                        let note = currentNote as BeamNote

                        title = note.title
                    })
                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }
                    .accessibility(identifier: "newSearch")
                    .buttonStyle(RoundRectButtonStyle())
                }.padding(.leading, 9)
            } else {
                BeamSearchBox(isEditing: $state.isEditingOmniBarTitle)
                    .onHover { (hover) in
                        if hover {
                            NSCursor.iBeam.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
            }

            if state.mode == .web {
                DestinationCardPicker(tab: state.currentTab!)
                    .frame(width: 200, height: 30, alignment: .center)
            }

            Button(action: toggleMode) {
                Symbol(name: state.mode == .web ? "note.text" : "network")
            }
            .accessibility(identifier: state.mode == .web ? "note" : "network")
            .buttonStyle(RoundRectButtonStyle()).disabled(state.tabs.isEmpty)
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
