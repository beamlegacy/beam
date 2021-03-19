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
    @Binding var isEditing: Bool {
        didSet {
            shouldCenter = !isEditing
        }
    }
    @Binding var modifierFlagsPressed: NSEvent.ModifierFlags?

    // this enables the call of didSet
    private var customEditingBinding: Binding<Bool> {
        return Binding<Bool>(get: {
            isEditing
        }, set: {
            isEditing  = $0
        })
    }

    @State private var shouldCenter: Bool = false

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
        return HStack(spacing: 8) {
            Icon(name: leadingIconName, size: 16, color: isEditing ? Color(.omniboxTextColor) : Color(.omniboxPlaceholderTextColor) )
                .opacity(shouldShowWebHost ? 0 : 1.0)
                .frame(width: shouldShowWebHost ? 0 : 16)
            BeamTextField(
                text: textFieldText,
                isEditing: customEditingBinding,
                placeholder: "Search Beam or the web",
                font: .systemFont(ofSize: 13),
                textColor: NSColor.omniboxTextColor,
                placeholderColor: NSColor.omniboxPlaceholderTextColor,
                selectedRanges: state.searchQuerySelectedRanges,
                onTextChanged: { _ in
                    state.resetAutocompleteSelection()
                },
                onCommit: { modifierFlags in
                    onEnterPressed(withCommand: modifierFlags?.contains(.command) ?? false)
                },
                onEscape: {
                    if state.autocompleteResults.isEmpty {
                        if state.searchQuery.isEmpty || state.mode == .web {
                            unfocusField()
                        } else {
                            state.resetQuery()
                        }
                    } else {
                        state.cancelAutocomplete()
                    }
                },
                onCursorMovement: { cursorMovement in
                    return handleCursorMovement(cursorMovement)
                },
                onModifierFlagPressed: { event in
                    modifierFlagsPressed = event.modifierFlags.contains(.command) ? .command : nil
                }
            )
            .centered(shouldCenter && state.mode != .web)
            .accessibility(addTraits: .isSearchField)
            .accessibility(identifier: "OmniBarSearchField")
        }
        .animation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.3))
    }

    func onEnterPressed(withCommand: Bool) {
        if withCommand {
            // Cmd+Enter select create card
            if let createCardIndex = state.autocompleteResults.firstIndex(where: { (result) -> Bool in
                return result.source == .createCard
            }) {
                state.autocompleteSelectedIndex = createCardIndex
            }
        }
        startQuery()
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

    func handleCursorMovement(_ move: CursorMovement) -> Bool {
        switch move {
        case .down, .up:
            NSCursor.setHiddenUntilMouseMoves(true)
            if move == .up {
                state.selectPreviousAutocomplete()
            } else {
                state.selectNextAutocomplete()
            }
            return true
        default:
            return false
        }
    }
}

struct OmniBarSearchField_Previews: PreviewProvider {
    static var previews: some View {
        OmniBarSearchField(isEditing: .constant(true), modifierFlagsPressed: .constant(nil)).environmentObject(BeamState())
            .frame(width: 400)
            .background(Color.white)
    }
}
