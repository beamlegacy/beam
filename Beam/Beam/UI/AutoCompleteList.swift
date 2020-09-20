//
//  AutoCompleteList.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI
import AppKit

struct AutoCompleteList: View {
    @Binding var selectedIndex: Int
    @Binding var elements: [AutoCompleteResult]

    var body: some View {
        List(elements) { i in
            AutoCompleteItem(item: i, selected: elements[selectedIndex].id == i.id)
        }.frame(maxWidth: .infinity)
    }
}

struct AutoCompleteList_Previews: PreviewProvider {
    static var elements = [AutoCompleteResult(string: "prout"), AutoCompleteResult(string: "asldkfjh sadlkfjh"), AutoCompleteResult(id: UUID(), string: "bleh blehbleh")]
    static var previews: some View {
        AutoCompleteList(selectedIndex: .constant(0), elements: .constant(Self.elements))
    }
}
