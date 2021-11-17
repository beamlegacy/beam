//
//  StepperControl.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/04/2021.
//

import SwiftUI

struct StepperControl: View {
    let min: Int
    let max: Int
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(String(value))
            VStack(spacing: 6) {
                Button(action: { value += 1 }, label: {
                    Image("plus")
                })
                .disabled(value >= max)
                .buttonStyle(PlainButtonStyle())
                Button(action: { value -= 1 }, label: {
                    Image("minus")
                })
                .disabled(value <= min)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct StepperControl_Previews: PreviewProvider {
    static var previews: some View {
        StepperControl(min: 1, max: 10, value: .constant(4))
    }
}
