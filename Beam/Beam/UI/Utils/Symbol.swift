//
//  SymbolView.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/10/2020.
//

import Foundation
import SwiftUI

struct Symbol: View {
    var name: String
    var size: Float = 16
    @Environment(\.isEnabled) var isEnabled
    let normalFg = Color("ToolbarButtonIconColor")
    let disabledFg = Color("ToolbarButtonIconDisabledColor")

    var body: some View {
        Image(name).renderingMode(.template)
            .resizable()
            .scaledToFill()
            .frame(width: CGFloat(size / (size >= 14 ? 2 : 1)), height: CGFloat(size), alignment: .center)
            .foregroundColor(isEnabled ? normalFg : disabledFg)
    }
}
