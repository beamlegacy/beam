//
//  DestinationNoteAutocompleteList.swift
//  Beam
//
//  Created by Remi Santos on 09/03/2021.
//

import SwiftUI

struct DestinationNoteAutocompleteList: View {
    @EnvironmentObject var state: BeamState
    @Binding var selectedIndex: Int?
    @Binding var elements: [AutocompleteResult]
    var modifierFlagsPressed: NSEvent.ModifierFlags?

    internal var onSelectAutocompleteResult: (() -> Void)?
    private let itemHeight: CGFloat = 32
    private let colorPalette = AutocompleteItemColorPalette(selectedBackgroundColor: .destinationNoteSelectedColor, touchdownBackgroundColor: .destinationNoteActiveColor)
    var body: some View {
        OmniBarFieldBackground(isEditing: true, enableAnimations: true) {
            VStack(spacing: 0) {
                ForEach(elements) { i in
                    return AutocompleteItem(item: i, selected: isSelectedItem(i), displayIcon: false, colorPalette: colorPalette)
                        .frame(height: itemHeight)
                        .simultaneousGesture(
                            TapGesture(count: 1).onEnded {
                                selectedIndex = indexFor(item: i)
                                onSelectAutocompleteResult?()
                            }
                        )
                        .onHover { hovering in
                            if hovering {
                                selectedIndex = indexFor(item: i)
                            }
                        }
                }
            }
            .animation(nil)
            .onHover { hovering in
                if !hovering {
                    selectedIndex = nil
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    func isSelectedItem(_ item: AutocompleteResult) -> Bool {
        if let i = selectedIndex {
            return elements[i].id == item.id
        } else if item.source == .createCard && modifierFlagsPressed?.contains(.command) == true {
            return true
        }
        return false
    }

    func indexFor(item: AutocompleteResult) -> Int? {
        for i in elements.indices where elements[i].id == item.id {
            return i
        }
        return nil
    }
}

extension DestinationNoteAutocompleteList {
    func onSelectAutocompleteResult(perform action: @escaping () -> Void ) -> Self {
         var copy = self
         copy.onSelectAutocompleteResult = action
         return copy
     }
}

struct DestinationNoteAutocompleteList_Previews: PreviewProvider {
    static var elements = [
        AutocompleteResult(text: "Result", source: .autocomplete),
        AutocompleteResult(text: "Result 2", source: .autocomplete),
        AutocompleteResult(text: "Result third", source: .autocomplete)]
    static var previews: some View {
        DestinationNoteAutocompleteList(selectedIndex: .constant(1), elements: .constant(Self.elements))
    }
}
