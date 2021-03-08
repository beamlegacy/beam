//
//  SymbolView.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/10/2020.
//

import Foundation
import SwiftUI

struct Icon: View {
    var name: String
    var size: Float = 16
    var color = Color(.toolbarButtonIconColor)

    var body: some View {
        Image(name).renderingMode(.template)
            .resizable()
            .scaledToFill()
            .foregroundColor(.white)
            .colorMultiply(color) // foregroundColor cannot be animated while colorMultiply can
            .frame(width: CGFloat(size / (size >= 14 ? 2 : 1)), height: CGFloat(size), alignment: .center)
    }
}
