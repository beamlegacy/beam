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
    var isTemplate: Bool = true

    var body: some View {
        Image(name)
            .resizable()
            .if(isTemplate) {
                $0.renderingMode(.template)
                    .foregroundColor(.white)
                    .colorMultiply(color) // foregroundColor cannot be animated while colorMultiply can
            }
            .scaledToFill()
            .frame(width: size?.width ?? width, height: size?.height ?? width, alignment: alignment)
    }
}
