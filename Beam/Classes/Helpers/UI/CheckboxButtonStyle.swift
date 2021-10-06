//
//  CheckboxButtonStyle.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/09/2021.
//

import Foundation
import SwiftUI

// This is a style made with the purpose of disabling the UI interaction effect when you click on a Button
// And to pass is configuration isPressed to other Views
public struct MinimalisticStyle: ButtonStyle {
    var isPressed: (Bool) -> Void

    func opacityTrick(confIsPressed: Bool) -> Double {
        isPressed(confIsPressed)
        return 1
    }
    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .opacity(opacityTrick(confIsPressed: configuration.isPressed))

    }
}

// This Button style can be changed from outside
public struct DarkenStyle: ButtonStyle {
    var isPressedFromOutside: Bool

    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.1 : 0)
            .brightness(isPressedFromOutside ? -0.1 : 0)
    }
}
