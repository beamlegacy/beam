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
        List(self.elements) { i in
                AutoCompleteItem(item: i, selected: isSelectedItem(i))
        }.frame(maxWidth: .infinity)
    }
    
    func isSelectedItem(_ item: AutoCompleteResult) -> Bool {
        if let i = selectedIndex {
            return elements[i].id == item.id
        }
        return false
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
