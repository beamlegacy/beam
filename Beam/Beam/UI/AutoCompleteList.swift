//
//  AutoCompleteList.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI
import AppKit

struct AutoCompleteList: View {
    @Binding var selectedIndex: Int?
    @Binding var elements: [AutoCompleteResult]
    
    var body: some View {
        VStack() {
            ForEach(elements) { i in
                return AutoCompleteItem(item: i, selected: isSelectedItem(i)).onTapGesture {
                    selectedIndex = indexFor(item: i)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .top).background(Color("transparent"))
    }
    
    func isSelectedItem(_ item: AutoCompleteResult) -> Bool {
        if let i = selectedIndex {
            return elements[i].id == item.id
        }
        return false
    }

    func indexFor(item: AutoCompleteResult) -> Int? {
        for (i, _) in elements.enumerated() {
            if elements[i].id == item.id {
                return i
            }
        }
        return nil
    }

}

struct AutoCompleteList_Previews: PreviewProvider {
    static var elements = [
        AutoCompleteResult(id: UUID(), string: "prout"),
        AutoCompleteResult(id: UUID(), string: "asldkfjh sadlkfjh"),
        AutoCompleteResult(id: UUID(), string: "bleh blehbleh")]
    static var previews: some View {
        AutoCompleteList(selectedIndex: .constant(1), elements: .constant(Self.elements))
    }
}
