//
//  OmniBarSearchField.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct OmniBarSearchField: View {
    @EnvironmentObject var state: BeamState
    @Binding var isEditing: Bool

    private var shouldShowWebHost: Bool {
        return state.mode == .web && !isEditing && state.currentTab != nil
    }

    private var textFieldText: Binding<String> {
        guard let tab = state.currentTab, let url = tab.url, shouldShowWebHost else {
            return $state.searchQuery
        }
        return .constant(url.minimizedHost)
    }

    private var leadingIconName: String {
        guard let tab = state.currentTab, let url = tab.url, state.mode == .web, state.searchQuery == url.absoluteString else {
            return "field-search"
        }
        return "field-web"

    }

    var body: some View {
        HStack(spacing: 8) {
            if !shouldShowWebHost {
                Icon(name: leadingIconName, size: 16, color: isEditing ? Color(.omniboxTextColor) : Color(.omniboxPlaceholderTextColor) )
            }
            BeamTextField(
                text: textFieldText,
                isEditing: $isEditing,
                placeholder: "Search Beam or the web",
                font: .systemFont(ofSize: 13),
                textColor: NSColor.omniboxTextColor,
                placeholderColor: NSColor.omniboxPlaceholderTextColor,
                selectedRanges: state.searchQuerySelectedRanges,
                onTextChanged: { _ in
                    state.resetAutocompleteSelection()
                },
                onCommit: {
                    startQuery()
                },
                onEscape: {
                    if state.autocompleteResults.isEmpty {
                        if state.searchQuery.isEmpty {
                            unfocusField()
                        } else {
                            state.resetQuery()
                        }
                    } else {
                        state.cancelAutocomplete()
                    }
                },
                onCursorMovement: { cursorMovement in
                    switch cursorMovement {
                    case .up:
                        state.selectPreviousAutocomplete()
                        return true
                    case .down:
                        state.selectNextAutocomplete()
                        return true
                    default:
                        return false
                    }
                }
            )
            .centered(!isEditing && state.mode != .web)
            .accessibility(addTraits: .isSearchField)
            .accessibility(identifier: "OmniBarSearchField")
        }
        .animation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.3))
    }

    func unfocusField() {
        isEditing = false
    }

    func startQuery() {
        if state.searchQuery.isEmpty {
            return
        }
        state.startQuery()
    }
}

struct OmniBarSearchField_Previews: PreviewProvider {
    static var previews: some View {
        OmniBarSearchField(isEditing: .constant(true)).environmentObject(BeamState())
            .frame(width: 400)
            .background(Color.white)
    }
}
