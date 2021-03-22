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

    // if the mouse is over an item when it appears, onHover is called
    // this helps prevent this unwanted behavior. (linear.app/beamapp/issue/BE-566)
    @State private var lastItemThatAppeared: [AutocompleteResult.ID: Date]?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(elements) { i in
                return AutocompleteItem(item: i, selected: isSelectedItem(i))
                    .frame(height: itemHeight)
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            selectedIndex = indexFor(item: i)
                            state.startQuery()
                        }
                    )
                    .onAppear {
                        lastItemThatAppeared = [i.id: Date()]
                    }
                    .onHover { hovering in
                        if hovering {
                            var timeSinceAppear: TimeInterval = 0.25
                            if let lastAppearedAt = lastItemThatAppeared?[i.id] {
                                timeSinceAppear = Date().timeIntervalSince(lastAppearedAt)
                                lastItemThatAppeared = nil
                            }
                            if timeSinceAppear >= 0.25 {
                                selectedIndex = indexFor(item: i)
                            }
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
        .frame(maxWidth: .infinity, alignment: .top)
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

struct AutocompleteList_Previews: PreviewProvider {
    static var elements = [
        AutocompleteResult(text: "prout", source: .autocomplete),
        AutocompleteResult(text: "asldkfjh sadlkfjh", source: .autocomplete),
        AutocompleteResult(text: "bleh blehbleh", source: .autocomplete)]
    static var previews: some View {
        AutocompleteList(selectedIndex: .constant(1), elements: .constant(Self.elements), modifierFlagsPressed: nil)
    }
}
