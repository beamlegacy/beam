//
//  OmniBarSearchBox.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct OmniBarSearchBox: View {
    var _cornerRadius = CGFloat(7)
    @EnvironmentObject var state: BeamState
    @Binding var isEditing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color("OmniboxBackgroundColor")) .frame(height: 28)
            RoundedRectangle(cornerRadius: _cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: isEditing ? 2.5 : 0).frame(height: 28)

            HStack {
                BTextField(text: $state.searchQuery,
                           isEditing: $isEditing,
                           placeholderText: "Search or create note... \(Note.countWithPredicate(CoreDataManager.shared.mainContext)) notes",
                           selectedRanges: state.searchQuerySelection,
                           onTextChanged: { _ in
                            state.resetAutocompleteSelection()
                           },
                           onCommit: {
                            startQuery()
                           },
                           onEscape: {
                            state.cancelAutocomplete()
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
                                break
                            }
                            return false
                           },
                           focusOnCreation: true,
                           textColor: NSColor(named: "OmniboxTextColor"),
                           placeholderTextColor: NSColor(named: "OmniboxPlaceholderTextColor"),
                           name: "OmniBarSearchBox"

                )
                .padding(.top, 8)
                .padding([.leading, .trailing], 9)
                .frame(idealWidth: 600, maxWidth: .infinity)

                Button(action: resetSearchQuery) {
                    Symbol(name: "xmark.circle.fill", size: 12)
                }.buttonStyle(BorderlessButtonStyle()).disabled(state.searchQuery.isEmpty).padding([.leading, .trailing], 9)
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
        }
    }
}
