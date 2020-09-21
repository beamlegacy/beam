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
            Text(item.string)
                .foregroundColor(selected ? .white :  .black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding([.top, .bottom], 3)
        .background(selected ? Color.accentColor : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8.0), style: FillStyle())

            
            
    }
}


struct AutoCompleteItem_Previews: PreviewProvider {
    static var previews: some View {
        Group {
        AutoCompleteItem(item: AutoCompleteResult(id: UUID(), string: "bleh qweerty"), selected: true)
        AutoCompleteItem(item: AutoCompleteResult(id: UUID(), string: "bleh qweerty"), selected: false)
        }
    }
}
