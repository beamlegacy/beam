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
    @EnvironmentObject var autocompleteManager: AutocompleteManager

    @Binding var isEditing: Bool {
        didSet {
            shouldCenter = !isEditing
        }
    }
    @Binding var modifierFlagsPressed: NSEvent.ModifierFlags?
    var enableAnimations: Bool = true

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
            return $autocompleteManager.searchQuery
        }
        return .constant(url.minimizedHost)
    }

    private var leadingIconName: String? {
        if let tab = state.currentTab, let url = tab.url, state.mode == .web, autocompleteManager.searchQuery == url.absoluteString {
            return "field-web"
        }
        return "field-search"
    }

    private var selectedAutocompleteResult: AutocompleteResult? {
        if let autocompleteIndex = autocompleteManager.autocompleteSelectedIndex, autocompleteIndex < autocompleteManager.autocompleteResults.count {
            return autocompleteManager.autocompleteResults[autocompleteIndex]
        }
        return nil
    }

    private var favicon: NSImage? {
        var icon: NSImage?
        if let autocompleteResult = selectedAutocompleteResult, let url = autocompleteResult.url, autocompleteResult.source == .history {
            FaviconProvider.shared.imageForUrl(url, cacheOnly: true) { (image) in
                icon = image
            }
        }
        return icon
    }

    private var resultSubtitle: String? {
        guard isEditing else { return nil }
        guard let autocompleteResult = selectedAutocompleteResult else { return nil }
        if let info = autocompleteResult.information {
            return info
        } else if autocompleteResult.source == .autocomplete {
            return Autocompleter.autocompleteResultDescription
        }
        return nil
    }

    private var textColor: BeamColor {
        guard !isEditing else { return BeamColor.Generic.text }
        guard textFieldText.wrappedValue.isEmpty else { return BeamColor.LightStoneGray }
        return BeamColor.Generic.placeholder
    }

    var body: some View {
        return HStack(spacing: 8) {
            if let icon = favicon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .opacity(shouldShowWebHost ? 0 : 1.0)
                    .frame(width: shouldShowWebHost ? 0 : 16)
            } else if let iconName = leadingIconName {
                Icon(name: iconName, size: 16, color: textColor.swiftUI)
                    .opacity(shouldShowWebHost ? 0 : 1.0)
                    .frame(width: shouldShowWebHost ? 0 : 16)
            }
            ZStack(alignment: .leading) {
                BeamTextField(
                    text: textFieldText,
                    isEditing: customEditingBinding,
                    placeholder: "Search Beam or the web",
                    font: BeamFont.medium(size: 13).nsFont,
                    textColor: textColor.nsColor,
                    placeholderColor: BeamColor.Generic.placeholder.nsColor,
                    selectedRanges: autocompleteManager.searchQuerySelectedRanges,
                    onTextChanged: { _ in
                        autocompleteManager.resetAutocompleteSelection()
                    },
                    onCommit: { modifierFlags in
                        onEnterPressed(withCommand: modifierFlags?.contains(.command) ?? false)
                    },
                    onEscape: {
                        if autocompleteManager.autocompleteResults.isEmpty {
                            if autocompleteManager.searchQuery.isEmpty || state.mode == .web {
                                unfocusField()
                            } else {
                                autocompleteManager.resetQuery()
                            }
                        } else {
                            autocompleteManager.cancelAutocomplete()
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
                .disabled(!isEditing) // Allow Window dragging
                .accessibility(addTraits: .isSearchField)
                .accessibility(identifier: "OmniBarSearchField")
                if let subtitle = resultSubtitle {
                    HStack(spacing: 0) {
                        Text(textFieldText.wrappedValue)
                            .font(BeamFont.medium(size: 13).swiftUI)
                            .foregroundColor(Color.purple)
                            .hidden()
                            .layoutPriority(10)
                        Text(" – \(subtitle)")
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Autocomplete.link.swiftUI)
                            .background(autocompleteManager.searchQuerySelectedRanges?.isEmpty == false ?
                                            BeamColor.Generic.textSelection.swiftUI :
                                            nil)
                            .offset(x: -0.5, y: 0)
                            .animation(nil)
                            .layoutPriority(0)
                    }
                    .lineLimit(1)

                }
            }
        }
        .animation(enableAnimations ? .timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.3) : nil)
    }

    func onEnterPressed(withCommand: Bool) {
        if withCommand {
            // Cmd+Enter select create card
            if let createCardIndex = autocompleteManager.autocompleteResults.firstIndex(where: { (result) -> Bool in
                return result.source == .createCard
            }) {
                autocompleteManager.autocompleteSelectedIndex = createCardIndex
            }
        }
        startQuery()
    }

    func unfocusField() {
        isEditing = false
    }

    func startQuery() {
        if autocompleteManager.searchQuery.isEmpty {
            return
        }
        state.startQuery()
    }

    func handleCursorMovement(_ move: CursorMovement) -> Bool {
        switch move {
        case .down, .up:
            NSCursor.setHiddenUntilMouseMoves(true)
            if move == .up {
                autocompleteManager.selectPreviousAutocomplete()
            } else {
                autocompleteManager.selectNextAutocomplete()
            }
            return true
        default:
            autocompleteManager.resetAutocompleteSelection()
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
