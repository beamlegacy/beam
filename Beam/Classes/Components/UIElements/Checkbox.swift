//
//  Checkbox.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/06/2021.
//

import SwiftUI

struct Checkbox: View {
    @State var checkState: Bool
    var text: String
    var textColor: Color
    var textFont: Font
    var activated: (Bool) -> Void

    var body: some View {
        HStack {
            Button(action: {
                checkState.toggle()
                activated(checkState)
            }, label: {
                Image(checkState ? "collect-generic" : "nil")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(.white)
                    .frame(width: 14, height: 14, alignment: .center)
                    .cornerRadius(4)
                    .background(
                        Rectangle()
                                 .fill(self.checkState ? Color.blue : Color.white)
                                 .frame(width: 14, height: 14, alignment: .center)
                                 .cornerRadius(4)
                    )
            })
            .buttonStyle(PlainButtonStyle())
            Text(text)
                .foregroundColor(textColor)
                .font(textFont)
        }
    }
}

struct Checkbox_Previews: PreviewProvider {
    static var previews: some View {
        Text("Beam")
        Checkbox(checkState: true, text: "This is a checkbox, please check me !", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI, activated: { _ in })
    }
}
