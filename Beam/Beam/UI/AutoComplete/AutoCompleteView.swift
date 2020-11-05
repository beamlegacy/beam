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
        ZStack {
            if !autoComplete.isEmpty {
                Rectangle().fill(Color("EditorBackgroundColor").opacity(0.8))
                AutoCompleteList(selectedIndex: $selectionIndex, elements: $autoComplete)
                    .padding([.leading, .trailing], CGFloat(150))
            }
        }
    }
}
