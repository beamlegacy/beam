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

    private let itemHeight: CGFloat = 32

    // on macOS < 11.0, onHover(false) is called on items that were not hovered before
    @State private var lastItemHovered: AutocompleteResult?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(elements) { i in
                return AutocompleteItem(item: i, selected: isSelectedItem(i),
                                        colorPalette: i.source == .createCard ?
                                            AutocompleteItemColorPalette(informationTextColor: BeamColor.Autocomplete.newCardSubtitle) :
                                            AutocompleteItem.defaultColorPalette)
                    .frame(height: itemHeight)
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            selectedIndex = indexFor(item: i)
                            state.startQuery()
                        }
                    )
                    .onHoverOnceVisible { hovering in
                        if hovering {
                            selectedIndex = indexFor(item: i)
                            lastItemHovered = i
                        } else if isSelectedItem(i) && lastItemHovered == i {
                            selectedIndex = nil
                        }
                    }
            }
        }
        .animation(nil)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    func isSelectedItem(_ item: AutocompleteResult) -> Bool {
        if modifierFlagsPressed?.contains(.command) == true {
            return item.source == .createCard
        } else if let i = selectedIndex, i < elements.count {
            return elements[i] == item
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
        AutocompleteResult(text: "prout", source: .autocomplete),
        AutocompleteResult(text: "asldkfjh sadlkfjh", source: .autocomplete),
        AutocompleteResult(text: "bleh blehbleh", source: .autocomplete)]
    static var previews: some View {
        AutocompleteList(selectedIndex: .constant(1), elements: .constant(Self.elements), modifierFlagsPressed: nil)
    }
}
