//
//  ToastTextIconView.swift
//  Beam
//
//  Created by Remi Santos on 12/07/2021.
//

import Foundation
import SwiftUI

struct ToastTextIconView: View {
    var text: String?
    var icon: String?

    var body: some View {
        HStack {
            if let icon = icon {
                Icon(name: icon, color: BeamColor.Generic.text.swiftUI)
            }
            if let text = text {
                Text(text)
                    .font(BeamFont.medium(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            }
        }.padding()
    }
}

struct ToastTextIconView_Previews: PreviewProvider {
    static var previews: some View {
        ToastTextIconView(text: "Some Toast", icon: "field-search")
    }
}
