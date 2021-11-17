//
//  OmniBarSearchField.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI
import Combine

struct OmniBarSearchField: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    @Binding var isEditing: Bool {
        didSet {
            editingDidChange(isEditing)
        }
    }
    @Binding var modifierFlagsPressed: NSEvent.ModifierFlags?
    var enableAnimations: Bool = true

    @State private var shouldCenter: Bool = true
    @State private var currentDisplayMode: Mode = .today

    private var shouldShowWebHost: Bool {
        currentDisplayMode == .web && !isEditing && browserTabsManager.currentTab != nil
    }

    private var textFieldText: Binding<String> {
        guard let tab = browserTabsManager.currentTab, let url = tab.url, shouldShowWebHost else {
            return $autocompleteManager.searchQuery
        }
        return .constant(url.minimizedHost ?? url.absoluteString)
    }

    private var leadingIconName: String? {
        if let tab = browserTabsManager.currentTab, let url = tab.url,
           currentDisplayMode == .web,
           autocompleteManager.searchQuery == url.absoluteString {
            return AutocompleteResult.Source.url.iconName
        }
        if let autocompleteResult = selectedAutocompleteResult {
            return autocompleteResult.source.iconName
        }
        return AutocompleteResult.Source.autocomplete.iconName
    }

    private var selectedAutocompleteResult: AutocompleteResult? {
        if let autocompleteIndex = autocompleteManager.autocompleteSelectedIndex, autocompleteIndex < autocompleteManager.autocompleteResults.count, autocompleteIndex >= 0 {
            return autocompleteManager.autocompleteResults[autocompleteIndex]
        }
        return nil
    }

    private var favicon: NSImage? {
        var icon: NSImage?
        if let autocompleteResult = selectedAutocompleteResult, let url = autocompleteResult.url,
           [.history, .url, .topDomain].contains(autocompleteResult.source) {
            FaviconProvider.shared.favicon(fromURL: url, cacheOnly: true) { (image) in
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
            return autocompleteManager.searchEngine.description
        }
        return nil
    }

    private var textColor: BeamColor {
        guard !isEditing else { return BeamColor.Generic.text }
        guard textFieldText.wrappedValue.isEmpty else { return BeamColor.LightStoneGray }
        return BeamColor.Generic.placeholder
    }

    private var subtitleColor: BeamColor {
        if let result = selectedAutocompleteResult, result.source == .createCard {
            return BeamColor.Autocomplete.newCardSubtitle
        }
        return BeamColor.Autocomplete.link
    }

    var body: some View {
        return HStack(spacing: 8) {
            if let icon = favicon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .opacity(shouldShowWebHost ? 0 : 1.0)
                    .frame(width: shouldShowWebHost ? 0 : 16)
                    .transition(.identity)
            } else if let iconName = leadingIconName {
                Icon(name: iconName, size: 16, color: textColor.swiftUI)
                    .opacity(shouldShowWebHost ? 0 : 1.0)
                    .frame(width: shouldShowWebHost ? 0 : 16)
                    .transition(.identity)
            }
            ZStack(alignment: .leading) {
                BeamTextField(
                    text: textFieldText,
                    isEditing: $isEditing.onChange(editingDidChange),
                    placeholder: "Search Beam or the web",
                    font: BeamFont.medium(size: 13).nsFont,
                    textColor: textColor.nsColor,
                    placeholderColor: BeamColor.Generic.placeholder.nsColor,
                    selectedRange: autocompleteManager.searchQuerySelectedRange,
                    textWillChange: { autocompleteManager.replacementTextForProposedText($0) },
                    onCommit: { modifierFlags in
                        onEnterPressed(withCommand: modifierFlags?.contains(.command) ?? false)
                    },
                    onEscape: onEscapePressed,
                    onCursorMovement: { handleCursorMovement($0) },
                    onModifierFlagPressed: { event in
                        modifierFlagsPressed = event.modifierFlags.contains(.command) ? .command : nil
                    }
                )
                .centered(shouldCenter && currentDisplayMode != .web)
                .disabled(!isEditing) // Allow Window dragging
                .accessibility(addTraits: .isSearchField)
                .accessibility(identifier: "OmniBarSearchField")
                if let subtitle = resultSubtitle, !textFieldText.wrappedValue.isEmpty {
                    HStack(spacing: 0) {
                        Text(textFieldText.wrappedValue)
                            .font(BeamFont.medium(size: 13).swiftUI)
                            .foregroundColor(Color.purple)
                            .hidden()
                            .layoutPriority(10)
                            .animation(nil)
                        GeometryReader { geo in
                            HStack {
                            let pixelRoundUp = geo.frame(in: .global).minX.truncatingRemainder(dividingBy: 1)
                                Text(" – \(subtitle)")
                                .font(BeamFont.regular(size: 13).swiftUI)
                                .foregroundColor(subtitleColor.swiftUI)
                                .background(autocompleteManager.searchQuerySelectedRange?.isEmpty == false ?
                                                BeamColor.Generic.textSelection.swiftUI :
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
        .animation(enableAnimations ? .timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.3) : nil)
        .onReceive(Just(state.mode)) { newMode in
            // Locally handling the state mode to manage animations
            DispatchQueue.main.async {
                currentDisplayMode = newMode
            }
        }
    }

    private func editingDidChange(_ isNowEditing: Bool) {
        // using an additional state var to avoid changing the centering too early
        // when first responder is stolen by another input, breaking the animations
        shouldCenter = !isNowEditing
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

    private func onEscapePressed() {
        if autocompleteManager.autocompleteResults.isEmpty {
            if autocompleteManager.searchQuery.isEmpty || currentDisplayMode == .web {
                unfocusField()
            } else {
                autocompleteManager.resetQuery()
            }
        } else {
            autocompleteManager.cancelAutocomplete()
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
