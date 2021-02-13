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
    @State var hover = false
    var bgColor: Color {
        item.source == .note ? Color(.editorBidirectionalLinkColor) : Color(.editorLinkColor)
    }

    var body: some View {
        HStack {
            switch item.source {
            case .history:
                Icon(name: "clock", color: selected ? .white : .black).padding(.trailing, 5)
            case .autoComplete:
                Icon(name: "magnifyingglass", color: selected ? .white : Color(.editorLinkColor)).padding(.trailing, 5)
            case .note:
                Icon(name: "note.text", color: selected ? .white : .black).padding(.trailing, 5)

            case .createCard:
                Icon(name: "note.text", color: selected ? .white : .black).padding(.trailing, 5)
            }

            if let title = item.title {
                HStack {
                    Text(title)
                        .font(.system(size: 11)).fontWeight(.bold)
                        .frame(height: 17, alignment: .leading)
                        .foregroundColor(selected ? .white :  Color(.editorTextColor))
                        .accessibility(identifier: selected ? "selected": "noSelected")
                    Divider()
                }
            }

            Text(item.string)
                .font(.system(size: 11)).fontWeight(.semibold)
                .frame(height: 17, alignment: .leading)
                .foregroundColor(selected ? .white :  Color(.editorTextColor))
                .accessibility(identifier: selected ? "selected": "noSelected")

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding([.top, .bottom], 3)
        .background(selected ? bgColor : (hover ? bgColor.opacity(0.2) : Color(.transparent)))
        .clipShape(RoundedRectangle(cornerRadius: 8.0), style: FillStyle())
        .onHover { v in
            hover = v
        }
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
