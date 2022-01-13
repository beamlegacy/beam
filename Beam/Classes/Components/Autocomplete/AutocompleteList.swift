//
//  AutocompleteList.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI
import AppKit

struct AutocompleteList: View {
    @EnvironmentObject var state: BeamState
    @Binding var selectedIndex: Int?
    @Binding var elements: [AutocompleteResult]
    var modifierFlagsPressed: NSEvent.ModifierFlags?

    @State private var hoveredItemIndex: Int?

    private func isItemSelectedByHovering(_ item: AutocompleteResult) -> Bool {
        hoveredItemIndex != nil && hoveredItemIndex != selectedIndex && hoveredItemIndex == indexFor(item: item)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(elements) { i in
                let isSelected = isSelectedItem(i)
                let isCreateCard = i.source == .createCard
                let allowsShortcut = isCreateCard || (isSelected && !isItemSelectedByHovering(i))
                if i.source == .createCard && elements.count > 1 {
                    Separator(horizontal: true, color: BeamColor.Autocomplete.separatorColor)
                        .blendModeLightMultiplyDarkScreen()
                        .padding(.vertical, BeamSpacing._40)
                }
                AutocompleteItem(item: i, selected: isSelected, allowsShortcut: allowsShortcut,
                                 colorPalette: i.source == .createCard ?
                                 AutocompleteItemColorPalette(informationTextColor: BeamColor.Autocomplete.newCardSubtitle) :
                                    AutocompleteItem.defaultColorPalette)
                    .padding(.horizontal, BeamSpacing._60)
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            selectedIndex = indexFor(item: i)
                            state.startQuery()
                        }
                    )
                    .onHoverOnceVisible { hovering in
                        let index = indexFor(item: i)
                        if hovering {
                            hoveredItemIndex = index
                        } else if hoveredItemIndex == index {
                            hoveredItemIndex = nil
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
            return item.source == .createCard
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
        AutocompleteResult(text: "Search Result 1", source: .autocomplete),
        AutocompleteResult(text: "Search Result 2", source: .autocomplete),
        AutocompleteResult(text: "Site Visited", source: .history, url: URL(string: "https://apple.com")),
        AutocompleteResult(text: "result.com", source: .url),
        AutocompleteResult(text: "My Own Note", source: .createCard)]
    static var previews: some View {
        AutocompleteList(selectedIndex: .constant(1), elements: .constant(Self.elements), modifierFlagsPressed: nil)
    }
}
