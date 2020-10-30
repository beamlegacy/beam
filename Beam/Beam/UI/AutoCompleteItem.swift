//
//  AutoCompleteItem.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI

struct AutoCompleteItem: View {
    @State var item: AutoCompleteResult
    var selected: Bool

    var body: some View {
        HStack {
            switch item.source {
            case .history:
                Symbol(name: "clock")
            case .autoComplete:
                Symbol(name: "magnifyingglass").foregroundColor(Color("EditorLinkColor"))
            case .note:
                Symbol(name: "note.text")
            }

            Text(item.string)
                .foregroundColor(selected ? Color("AutoCompleteTextSelected") :  Color("AutoCompleteText"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding([.top, .bottom], 3)
        .background(selected ? Color.accentColor : Color("transparent"))
        .clipShape(RoundedRectangle(cornerRadius: 8.0), style: FillStyle())
    }
}

struct AutoCompleteItem_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AutoCompleteItem(item: AutoCompleteResult(id: UUID(), string: "bleh qweerty", source: .autoComplete), selected: true)
        AutoCompleteItem(item: AutoCompleteResult(id: UUID(), string: "bleh qweerty", source: .autoComplete), selected: false)
        }
    }
}
