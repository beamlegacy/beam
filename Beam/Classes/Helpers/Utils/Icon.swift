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
    var size: CGFloat = 16
    var color = BeamColor.Button.text.swiftUI
    var alignment: Alignment = .center

    var body: some View {
        Image(name).renderingMode(.template)
            .resizable()
            .scaledToFill()
            .foregroundColor(.white)
            .colorMultiply(color) // foregroundColor cannot be animated while colorMultiply can
            .frame(width: size, height: size, alignment: alignment)
            .border(Color.black)
    }
}
