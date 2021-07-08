//
//  Checkbox.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/06/2021.
//

import SwiftUI

struct Checkbox: View {
    @State var checkState: Bool
    var text: String?
    var textColor: Color?
    var textFont: Font?
    var activated: (Bool) -> Void

    var body: some View {
        HStack {
            Button(action: {
                checkState.toggle()
                activated(checkState)
            }, label: {
                if checkState {
                    Image("collect-generic")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 14, height: 14, alignment: .center)
                        .cornerRadius(4)
                        .background(
                            Rectangle()
                                     .fill(Color.blue)
                                     .frame(width: 14, height: 14, alignment: .center)
                                     .cornerRadius(4)
                        )
                } else {
                    Rectangle()
                             .fill(Color.white)
                             .frame(width: 14, height: 14, alignment: .center)
                             .cornerRadius(4)
                }
            })
            .buttonStyle(PlainButtonStyle())
            if !(text?.isEmpty ?? false) {
                Button {
                    checkState.toggle()
                    activated(checkState)
                } label: {
                    Text(text ?? "")
                        .foregroundColor(textColor)
                        .font(textFont)
                }.buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct Checkbox_Previews: PreviewProvider {
    static var previews: some View {
        Text("Beam")
        Checkbox(checkState: true, text: "This is a checkbox, please check me !", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI, activated: { _ in })
    }
}
