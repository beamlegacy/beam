//
//  ActionableButton+Gradient.swift
//  Beam
//
//  Created by Remi Santos on 08/11/2021.
//

import SwiftUI

extension ActionableButton {
    static func gradientStyle(icon: String? = nil) -> ActionableButtonVariant {
        var baseStyle = ActionableButtonVariant.secondary.style
        let foreground = BeamColor.From(color: .white)
        let foregroundPalette = ActionableButtonState.Palette(normal: foreground, hovered: foreground, clicked: foreground, disabled: foreground)
        baseStyle.textAlignment = .center
        baseStyle.foregroundColor = foregroundPalette
        if let icon = icon {
            baseStyle.icon = .init(name: icon, palette: foregroundPalette)
        } else {
            baseStyle.icon = nil
        }
        baseStyle.customBackground = { AnyView(AnimatedGradient()) }
        return ActionableButtonVariant.custom(baseStyle)
    }
}

struct ActionableButtonGradient_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ActionableButton(text: "Actionable Button", defaultState: .normal, variant: ActionableButton.gradientStyle())
            ActionableButton(text: "Press Enter", defaultState: .normal, variant: ActionableButton.gradientStyle(icon: "editor-format_enter"))
        }
        .padding()
    }
}
