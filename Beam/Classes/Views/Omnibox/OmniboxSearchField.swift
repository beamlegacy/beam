//
//  OmniboxSearchField.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI
import Combine

struct OmniboxSearchField: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    @Binding var isEditing: Bool
    @Binding var modifierFlagsPressed: NSEvent.ModifierFlags?
    var enableAnimations: Bool = true

    private var textFieldText: Binding<String> {
        $autocompleteManager.searchQuery
    }

    private var leadingIconName: String? {
        if let tab = browserTabsManager.currentTab, let url = tab.url,
           state.mode == .web,
           autocompleteManager.searchQuery == url.absoluteString {
            return AutocompleteResult.Source.url.iconName
        }
        if let autocompleteResult = selectedAutocompleteResult {
            return autocompleteResult.icon
        }
        return AutocompleteResult.Source.searchEngine.iconName
    }

    private var selectedAutocompleteResult: AutocompleteResult? {
        return autocompleteManager.autocompleteResult(at: autocompleteManager.autocompleteSelectedIndex)
    }

    private var favicon: NSImage? {
        var icon: NSImage?
        if let autocompleteResult = selectedAutocompleteResult, let url = autocompleteResult.url,
           [.history, .url, .topDomain, .mnemonic].contains(autocompleteResult.source) {
            FaviconProvider.shared.favicon(fromURL: url, cacheOnly: true) { favicon in
                icon = favicon?.image
                if favicon == nil, let aliasDestinationURL = autocompleteResult.aliasForDestinationURL {
                    FaviconProvider.shared.favicon(fromURL: aliasDestinationURL, cacheOnly: true) { favicon in
                        icon = favicon?.image
                    }
                }
            }
        } else if state.focusOmniBoxFromTab,
                  let tab = browserTabsManager.currentTab, textFieldText.wrappedValue == tab.url?.absoluteString,
                  let favicon = tab.favIcon {
            icon = favicon
        }
        return icon
    }

    private var resultSubtitle: String? {
        guard isEditing else { return nil }
        guard let autocompleteResult = selectedAutocompleteResult else { return nil }
        if let info = autocompleteResult.displayInformation {
            return info
        } else if autocompleteResult.source == .searchEngine {
            return autocompleteManager.searchEngine.description
        }
        return nil
    }

    private var textColor: BeamColor {
        guard !isEditing else { return BeamColor.Generic.text }
        return BeamColor.Generic.placeholder
    }

    private var subtitleColor: BeamColor {
        if let result = selectedAutocompleteResult, result.source == .createNote {
            return BeamColor.Autocomplete.newCardSubtitle
        }
        return BeamColor.Autocomplete.link
    }
    private var textSelectionColor: BeamColor {
        BeamColor.Generic.blueTextSelection
    }
    private let textFont = BeamFont.regular(size: 17)

    var body: some View {
        HStack(spacing: BeamSpacing._120) {
            if let icon = favicon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                    .transition(.identity)
            } else if let iconName = leadingIconName {
                Icon(name: iconName, width: 16, color: BeamColor.LightStoneGray.swiftUI)
                    .transition(.identity)
            }
            ZStack(alignment: .leading) {
                BeamTextField(
                    text: textFieldText,
                    isEditing: $isEditing,
                    placeholder: "Search the web and your notes",
                    font: textFont.nsFont,
                    textColor: textColor.nsColor,
                    placeholderFont: BeamFont.light(size: 17).nsFont,
                    placeholderColor: BeamColor.Generic.placeholder.nsColor,
                    selectedRange: autocompleteManager.searchQuerySelectedRange,
                    selectedRangeColor: textSelectionColor.nsColor,
                    textWillChange: { autocompleteManager.replacementTextForProposedText($0) },
                    onCommit: { modifierFlags in
                        onEnterPressed(modifierFlags: modifierFlags)
                    },
                    onEscape: onEscapePressed,
                    onCursorMovement: { handleCursorMovement($0) },
                    onModifierFlagPressed: { event in
                        modifierFlagsPressed = event.modifierFlags
                    }
                )
                    .frame(maxHeight: .infinity)
                    .accessibility(addTraits: .isSearchField)
                    .accessibility(identifier: "OmniboxSearchField")
                if let subtitle = resultSubtitle, !textFieldText.wrappedValue.isEmpty {
                    HStack(spacing: 0) {
                        Text(textFieldText.wrappedValue)
                            .font(textFont.swiftUI)
                            .foregroundColor(Color.purple)
                            .hidden()
                            .layoutPriority(10)
                        GeometryReader { geo in
                            HStack {
                            let pixelRoundUp = geo.frame(in: .global).minX.truncatingRemainder(dividingBy: 1)
                                Text(" – \(subtitle)")
                                .font(textFont.swiftUI)
                                .foregroundColor(subtitleColor.swiftUI)
                                .background(autocompleteManager.searchQuerySelectedRange?.isEmpty == false ?
                                            textSelectionColor.swiftUI :
                                                nil)
                                // We need to stick the subtitle exactly after the text selection
                                // text length might end up "in between pixels", so we need to offset that point-pixel roundup.
                                .offset(x: pixelRoundUp, y: 0)
                                .layoutPriority(0)
                                .animation(nil)
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .lineLimit(1)
                }
            }
        }
        .animation(nil)
    }

    func onEnterPressed(modifierFlags: NSEvent.ModifierFlags?) {
        let isCreateCardShortcut = modifierFlags?.contains(.option) == true
        if isCreateCardShortcut {
            if let createCardIndex = autocompleteManager.autocompleteResults.firstIndex(where: { (result) -> Bool in
                return result.source == .createNote
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
        case .right, .left:
            return autocompleteManager.handleLeftRightCursorMovement(move)
        }
    }

    private func onEscapePressed() {
        let query = autocompleteManager.searchQuery
        if query.isEmpty || (state.mode == .web && query == state.browserTabsManager.currentTab?.url?.absoluteString) {
            unfocusField()
        } else {
            autocompleteManager.setQuery("", updateAutocompleteResults: true)
        }
    }
}

struct OmniboxSearchField_Previews: PreviewProvider {
    static var previews: some View {
        OmniboxSearchField(isEditing: .constant(true), modifierFlagsPressed: .constant(nil)).environmentObject(BeamState())
            .frame(width: 400)
            .background(Color.white)
    }
}
