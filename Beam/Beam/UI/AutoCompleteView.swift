//
//  AutoCompleteView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import VisualEffects

struct AutoCompleteView: View {
    @Binding var autoComplete: [AutoCompleteResult]
    @Binding var selectionIndex: Int?
    var body: some View {
        if !autoComplete.isEmpty {
            return AnyView(
                ZStack {
                    VisualEffectBlur(material: .headerView, blendingMode: .withinWindow, state: .active)
                    Rectangle().fill(Color("EditorBackgroundColor").opacity(0.8))
                    AutoCompleteList(selectedIndex: $selectionIndex, elements: $autoComplete)
                        .padding([.leading, .trailing], CGFloat(150))
                }
            )
        } else {
//            return AnyView(Text(""))
            return AnyView(BTextEdit().frame(alignment: .center))
        }
    }
}
