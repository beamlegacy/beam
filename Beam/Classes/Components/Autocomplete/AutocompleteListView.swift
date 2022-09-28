//
//  AutocompleteListView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI
import AppKit
import BeamCore

struct AutocompleteListView: View {
    @EnvironmentObject var state: BeamState
    @Environment(\.undoManager) var undoManager
    @Binding var selectedIndex: Int?
    var elements: [AutocompleteResult]
    var loadingElement: AutocompleteResult?
    var modifierFlagsPressed: NSEvent.ModifierFlags?

    @State private var hoveredItemIndex: Int?

    private func isItemSelectedByHovering(_ item: AutocompleteResult) -> Bool {
        hoveredItemIndex != nil && hoveredItemIndex != selectedIndex && hoveredItemIndex == indexFor(item: item)
    }

    private func shouldItemDisplaySubtitle(_ item: AutocompleteResult, atIndex: Int) -> Bool {
        item.source != .searchEngine || atIndex <= 0 || elements[atIndex-1].information != item.information
    }

    static func colorPalette(for item: AutocompleteResult, mode: AutocompleteManager.Mode = .general) -> AutocompleteItemColorPalette {
        if case .tabGroup(let group) = mode {
            return AutocompleteItemView.tabGroupColorPalette(for: group)
        }
        switch item.source {
        case .action:
            return AutocompleteItemView.actionColorPalette
        case .note:
            return AutocompleteItemView.noteColorPalette
        case .tabGroup(let group):
            guard let group = group else { fallthrough }
            return AutocompleteItemView.tabGroupColorPalette(for: group)
        case .createNote:
            return item.information != nil ? AutocompleteItemView.createNoteColorPalette : AutocompleteItemView.actionColorPalette
        default:
            return AutocompleteItemView.defaultColorPalette
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(elements.enumerated()), id: \.1.id) { (index, item) in
                let isSelected = isSelectedItem(item)
                let displaySubtitle = shouldItemDisplaySubtitle(item, atIndex: index)
                let allowsShortcut = item.shortcut != nil || (isSelected && !isItemSelectedByHovering(item))
                VStack(spacing: 0) { // wrapping to fix issues with multiple views returned in a ForEach on BigSur 
                    if item.shouldDisplayTopDivider && elements.count > 1 && index > 0 {
                        Separator(horizontal: true, color: BeamColor.Autocomplete.separatorColor)
                            .blendModeLightMultiplyDarkScreen()
                            .padding(.vertical, BeamSpacing._60)
                    }
                    AutocompleteItemView(item: item, selected: isSelected, loading: loadingElement?.id == item.id,
                                         displaySubtitle: displaySubtitle,
                                         allowsShortcut: allowsShortcut,
                                         colorPalette: Self.colorPalette(for: item, mode: state.autocompleteManager.animatingToMode ?? state.autocompleteManager.mode),
                                         modifierFlagsPressed: modifierFlagsPressed)
                    .padding(.horizontal, BeamSpacing._60)
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            state.startOmniboxQuery(selectingNewIndex: indexFor(item: item), modifierFlags: modifierFlagsPressed)
                        }
                    )
                    .onHoverOnceVisible { hovering in
                        let index = indexFor(item: item)
                        if hovering {
                            hoveredItemIndex = index
                        } else if hoveredItemIndex == index {
                            hoveredItemIndex = nil
                        }
                    }
                    .contextMenu {
                        if let noteId = item.source.noteId {
                            BeamNote.contextMenu(for: noteId, state: state, undoManager: undoManager)
                        }
                    }
                }
            }
        }
        .padding(.vertical, BeamSpacing._60)
        .animation(nil)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    func isSelectedItem(_ item: AutocompleteResult) -> Bool {
        if modifierFlagsPressed?.contains(.option) == true {
            return item.source == .createNote
        } else if let i = selectedIndex, i < elements.count, elements[i] == item {
            return true
        } else if let i = hoveredItemIndex, i < elements.count, elements[i] == item {
            return true
        }
        return false
    }

    func indexFor(item: AutocompleteResult) -> Int? {
        for i in elements.indices where elements[i] == item {
            return i
        }
        return nil
    }

}

struct AutocompleteList_Previews: PreviewProvider {
    static var elements = [
        AutocompleteResult(text: "Search Result 1", source: .searchEngine),
        AutocompleteResult(text: "Search Result 2", source: .searchEngine),
        AutocompleteResult(text: "Site Visited", source: .history, url: URL(string: "https://apple.com")),
        AutocompleteResult(text: "result.com", source: .url, urlFields: .text),
        AutocompleteResult(text: "My Own Note", source: .createNote)]
    static var previews: some View {
        AutocompleteListView(selectedIndex: .constant(1), elements: Self.elements, modifierFlagsPressed: nil)
    }
}
