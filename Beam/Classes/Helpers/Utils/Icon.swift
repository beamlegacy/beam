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
    var width: CGFloat = 16
    var size: CGSize?
    var color = BeamColor.Button.text.swiftUI
    var alignment: Alignment = .center

    var body: some View {
        Image(name).renderingMode(.template)
            .resizable()
            .scaledToFill()
            .foregroundColor(.white)
            .colorMultiply(color) // foregroundColor cannot be animated while colorMultiply can
            .frame(width: size?.width ?? width, height: size?.height ?? width, alignment: alignment)
    }
}
