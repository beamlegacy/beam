//
//  AutoCompleteView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

struct AutoCompleteView: View {
    @Binding var autoComplete: [AutoCompleteResult]
    @Binding var selectionIndex: Int?
    var body: some View {
        if autoComplete.count != 0 {
            return AnyView(
                AutoCompleteList(selectedIndex: $selectionIndex, elements: $autoComplete)
            .padding([.leading, .trailing], CGFloat(150))
            )
        } else {
            return AnyView(Text(""))
//            return AnyView(BTextEdit())
        }
    }
}
