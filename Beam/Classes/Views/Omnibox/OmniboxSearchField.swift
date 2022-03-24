//
//  OmniboxSearchField.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI
import Combine
import BeamCore

struct OmniboxSearchField: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    @Binding var isEditing: Bool
    @Binding var modifierFlagsPressed: NSEvent.ModifierFlags?

    private var textFieldText: Binding<String> {
        $autocompleteManager.searchQuery
    }

    private func placeholder(for mode: AutocompleteManager.Mode) -> String {
        if mode == .noteCreation {
            return loc("Create Note")
        }
        return loc("Search the web and your notes")
    }

    private func leadingIconName(for mode: AutocompleteManager.Mode) -> String? {
        if let tab = browserTabsManager.currentTab, let url = tab.url,
           state.mode == .web,
           autocompleteManager.searchQuery == url.absoluteString {
            return AutocompleteResult.Source.url.iconName
        } else if let autocompleteResult = selectedAutocompleteResult {
            return autocompleteResult.icon
        } else if mode == .noteCreation {
            return AutocompleteResult.Source.createNote.iconName
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
        } else if state.omniboxInfo.wasFocusedFromTab,
                  let tab = browserTabsManager.currentTab, textFieldText.wrappedValue == tab.url?.absoluteString,
                  let favicon = tab.favIcon {
            icon = favicon
        }
        return icon
    }

    private var resultSubtitle: String? {
        guard isEditing, autocompleteManager.mode == .general else { return nil }
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
    private let placeholderFont = BeamFont.light(size: 17)
    private let placeholderColor = BeamColor.Generic.placeholder

    var body: some View {
        HStack(spacing: BeamSpacing._120) {
            if let icon = favicon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                    .transition(.identity)
            } else if let iconName = leadingIconName(for: autocompleteManager.mode) {
                Icon(name: iconName, width: 16, color: BeamColor.LightStoneGray.swiftUI)
                    .transition(.identity)
            }
            ZStack(alignment: .leading) {
                BeamTextField(
                    text: textFieldText,
                    isEditing: $isEditing,
                    placeholder: placeholder(for: autocompleteManager.mode),
                    font: textFont.nsFont,
                    textColor: textColor.nsColor,
                    placeholderFont: placeholderFont.nsFont,
                    placeholderColor: placeholderColor.nsColor,
                    selectedRange: autocompleteManager.searchQuerySelectedRange,
                    selectedRangeColor: textSelectionColor.nsColor,
                    textWillChange: { autocompleteManager.replacementTextForProposedText($0) },
                    onCommit: { modifierFlags in
                        onEnterPressed(modifierFlags: modifierFlags)
                    },
                    onEscape: onEscapePressed,
                    onBackspace: onBackspacePressed,
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
        // UITests on BigSur fails when setting textfield opacity to zero.
        .opacity(autocompleteManager.animatingToMode != nil ? 0.01 : 1)
        .overlay(animatingToModeOverlay(with: autocompleteManager))
    }

    func onEnterPressed(modifierFlags: NSEvent.ModifierFlags?) {
        let isCreateCardShortcut = modifierFlags?.contains(.option) == true
        if isCreateCardShortcut {
            if let createCardIndex = autocompleteManager.autocompleteResults.firstIndex(where: { (result) -> Bool in
                return result.source == .createNote
            }) {
                state.startOmniboxQuery(selectingNewIndex: createCardIndex)
                return
            }
        }
        guard !autocompleteManager.searchQuery.isEmpty else { return }
        state.startOmniboxQuery()
    }

    func unfocusField() {
        isEditing = false
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
        if (query.isEmpty && autocompleteManager.mode == state.omniboxInfo.wasFocusedDirectlyFromMode) ||
            (state.mode == .web && query == state.browserTabsManager.currentTab?.url?.absoluteString) {
            unfocusField()
            if state.omniboxInfo.isShownInJournal {
                autocompleteManager.clearAutocompleteResults()
            }
        } else {
            autocompleteManager.mode = .general
            autocompleteManager.setQuery("", updateAutocompleteResults: true)
        }
    }

    private func onBackspacePressed() {
        if autocompleteManager.searchQuery.isEmpty && (autocompleteManager.mode != state.omniboxInfo.wasFocusedDirectlyFromMode) {
            autocompleteManager.mode = .general
            autocompleteManager.setQuery("", updateAutocompleteResults: true)
        }
    }
}

// MARK: Mode Animations
extension OmniboxSearchField {
    fileprivate func animatingToModeOverlay(with autocompleteManager: AutocompleteManager) -> some View {
        let isAnimating = autocompleteManager.animatingToMode != nil
        return Color.clear
            .overlay(!isAnimating ? nil : fakeSearchField(for: autocompleteManager.mode, animatingOut: true),
                     alignment: .leading)
            .overlay(!isAnimating ? nil : fakeSearchField(for: autocompleteManager.animatingToMode ?? .general, animatingOut: false),
                     alignment: .leading)
            .allowsHitTesting(false)
    }

    private func fakeSearchField(for mode: AutocompleteManager.Mode, animatingOut: Bool) -> some View {
        var transition: AnyTransition
        if animatingOut {
            transition = .asymmetric(insertion: .modifier(active: _OpacityEffect(opacity: 1), identity: _OpacityEffect(opacity: 0))
                                        .combined(with: .animatableOffset(offset: CGSize(width: 0, height: 10)))
                                        .animation(BeamAnimation.easeInOut(duration: 0.1)),
                                     removal: .identity)
        } else {
            transition = .asymmetric(insertion: .opacity
                                        .combined(with: .animatableOffset(offset: CGSize(width: 0, height: 10)))
                                        .animation(BeamAnimation.easeInOut(duration: 0.1).delay(0.05)),
                                     removal: .identity)
        }
        return HStack(spacing: BeamSpacing._120) {
            if let iconName = leadingIconName(for: mode) {
                Icon(name: iconName, width: 16, color: BeamColor.LightStoneGray.swiftUI)
            }
            Text(placeholder(for: mode))
                .font(textFont.swiftUI)
                .foregroundColor(placeholderColor.swiftUI)
        }
        .offset(x: 0, y: animatingOut ? -10 : 0)
        .transition(transition)
    }

}

struct OmniboxSearchField_Previews: PreviewProvider {
    static var previews: some View {
        OmniboxSearchField(isEditing: .constant(true), modifierFlagsPressed: .constant(nil)).environmentObject(BeamState())
            .frame(width: 400)
            .background(Color.white)
    }
}
