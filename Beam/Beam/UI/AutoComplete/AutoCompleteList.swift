//
//  AutoCompleteList.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI
import AppKit

struct AutoCompleteList: View {
    @EnvironmentObject var state: BeamState
    @Binding var selectedIndex: Int?
    @Binding var elements: [AutoCompleteResult]

    var body: some View {
        VStack {
            ForEach(elements) { i in
                return AutoCompleteItem(item: i, selected: isSelectedItem(i))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1) {
                        selectedIndex = indexFor(item: i)
                        state.startQuery()
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color("transparent"))
    }

    func isSelectedItem(_ item: AutoCompleteResult) -> Bool {
        if let i = selectedIndex {
            return elements[i].id == item.id
        }
        return false
    }

    func indexFor(item: AutoCompleteResult) -> Int? {
        for i in elements.indices where elements[i].id == item.id {
            return i
        }
        return nil
    }

}

struct AutoCompleteList_Previews: PreviewProvider {
    static var elements = [
        AutoCompleteResult(id: UUID(), string: "prout", source: .autoComplete),
        AutoCompleteResult(id: UUID(), string: "asldkfjh sadlkfjh", source: .autoComplete),
        AutoCompleteResult(id: UUID(), string: "bleh blehbleh", source: .autoComplete)]
    static var previews: some View {
        AutoCompleteList(selectedIndex: .constant(1), elements: .constant(Self.elements))
    }
}
