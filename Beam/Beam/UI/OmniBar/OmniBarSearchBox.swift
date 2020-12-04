//
//  OmniBarSearchBox.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct BeamSearchBox: View {
    @EnvironmentObject var state: BeamState
    var canSearch: Bool {
        return !state.searchQuery.isEmpty || !isEditing
    }
    @Binding var isEditing: Bool

    var body: some View {
        ZStack {
            HStack {
                if isEditing || state.mode == .today {
                    OmniBarSearchBox(isEditing: $isEditing)
                } else {
                    Spacer()
                        .frame(height: 28)
                        .padding(.top, 8)
                }

                Button(action: isEditing ? startQuery : startNewSearch) {
                    Symbol(name: "magnifyingglass")
                }
                .disabled(!canSearch)
                .buttonStyle(RoundRectButtonStyle())
                .padding(.leading, 1)

                Button(action: startNewSearch) {
                    Symbol(name: "plus")
                }
                .buttonStyle(RoundRectButtonStyle())
            }.padding(.leading, 9)
        }
    }

    func startNewSearch() {
        state.startNewSearch()
    }

    func startQuery() {
        withAnimation {
            //print("searchText activated: \(searchText)")
            if state.searchQuery.isEmpty {
                state.currentNote = nil
            } else {
                state.startQuery()
                isEditing = false
            }
        }
    }
}

struct OmniBarSearchBox: View {
    @EnvironmentObject var state: BeamState
    @Binding var isEditing: Bool

    var _cornerRadius = CGFloat(7)

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: _cornerRadius)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: isEditing ? 3 : 0)
                    .frame(height: 28)

                HStack {
                    BMTextField(
                        text: $state.searchQuery,
                        isEditing: $isEditing,
                        isFirstResponder: state.isFirstResponder,
                        placeholder: "Search or create note... \(Note.countWithPredicate(CoreDataManager.shared.mainContext)) notes",
                        selectedRanges: state.searchQuerySelection,
                        onTextChanged: { _ in
                            state.resetAutocompleteSelection()
                        },
                        onCommit: {
                            startQuery()
                        },
                        onEscape: {
                            if state.completedQueries.isEmpty {
                                state.searchQuery = ""
                            } else {
                                state.cancelAutocomplete()
                            }
                        },
                        onCursorMovement: { cursorMovement in
                            switch cursorMovement {
                            case .up:
                                state.selectPreviousAutoComplete()
                                return true
                            case .down:
                                state.selectNextAutoComplete()
                                return true
                            default:
                                return false
                            }
                        }
                    )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)

                    Image("xmark.circle.fill")
                        .resizable()
                        .frame(width: 12, height: 12)
                        .offset(x: -7)
                        .animation(.default)
                        .opacity(isEditing && !state.searchQuery.isEmpty ? 1 : 0)
                        .onTapGesture(count: 1) {
                            resetSearchQuery()
                            NSApp.mainWindow?.makeFirstResponder(nil)
                        }
                }
                .padding([.top, .bottom], 7)
                .background(Color("OmniboxBackgroundColor"))
                .cornerRadius(_cornerRadius)
            }
        }
    }

    func resetSearchQuery() {
        withAnimation {
            state.startNewSearch()
        }
    }

    func startQuery() {
        if state.searchQuery.isEmpty {
            return
        }

        withAnimation {
            //print("searchText activated: \(searchText)")
            state.startQuery()
            isEditing = false
        }
    }
}
