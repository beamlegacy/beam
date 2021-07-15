//
//  BeamStepperButton.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 08/06/2021.
//

import SwiftUI

struct BeamStepperButton: View {
    var leftBtnAction: () -> Void
    var rightBtnAction: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.green)
                .frame(width: 65, height: 20)
            HStack {
                Button(action: leftBtnAction) {
                    Image("basicAdd")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.background.swiftUI)
                        .frame(width: 10, height: 10, alignment: .center)
                }.buttonStyle(PlainButtonStyle())

                Button(action: rightBtnAction) {
                    Image("basicRemove")
                        .renderingMode(.template)
                        .foregroundColor(BeamColor.Generic.background.swiftUI)
                        .frame(width: 10, height: 10, alignment: .center)
                }.buttonStyle(PlainButtonStyle())

            }
        }
    }
}

struct BeamStepper_Previews: PreviewProvider {
    static var previews: some View {
        BeamStepperButton(leftBtnAction: {}, rightBtnAction: {}).frame(width: 65, height: 20, alignment: .center)
    }
}
