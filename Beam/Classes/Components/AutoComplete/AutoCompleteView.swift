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
        VStack {
            ZStack {
                    Rectangle().fill(Color(.editorBackgroundColor).opacity(0.8))
                    AutoCompleteList(selectedIndex: $selectionIndex, elements: $autoComplete)
                        .padding([.leading, .trailing], CGFloat(185))
            }
            Rectangle().fill(Color(.editorTextRectangleBackgroundColor)).frame(height: 1, alignment: .top)
        }
    }
}
