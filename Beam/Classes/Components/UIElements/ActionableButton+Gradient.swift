//
//  ActionableButton+Gradient.swift
//  Beam
//
//  Created by Remi Santos on 08/11/2021.
//

import SwiftUI

extension ActionableButtonVariant {
    private struct GradientActionableButtonCustomBackground: View {
        var state: ActionableButtonState
        private var overlayOpacity: Double {
            switch state {
            case .clicked:
                return 0.4
            case .hovered:
                return 0.22
            default:
                return 0
            }
        }
        var body: some View {
            Group {
                if state != .disabled {
                    AnimatedGradient()
                        .overlay(
                            Color.black.opacity(overlayOpacity)
                        )
                }
            }
        }
    }

    static func gradient(icon: String? = nil) -> ActionableButtonVariant {
        var baseStyle = ActionableButtonVariant.primaryPurple.style
        let foreground = BeamColor.From(color: .white)
        let foregroundPalette = ActionableButtonState.Palette(normal: foreground, hovered: foreground, clicked: foreground, disabled: baseStyle.foregroundColor.disabled)
        baseStyle.foregroundColor = foregroundPalette
        if let icon = icon {
            baseStyle.icon = .init(name: icon, palette: foregroundPalette)
        } else {
            baseStyle.icon = nil
        }
        baseStyle.customBackground = { AnyView(GradientActionableButtonCustomBackground(state: $0)) }
        return ActionableButtonVariant.custom(baseStyle)
    }
}

struct ActionableButtonGradient_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ActionableButton(text: "Actionable Button", defaultState: .normal, variant: .gradient())
            ActionableButton(text: "Press Enter", defaultState: .normal, variant: .gradient(icon: "shortcut-return"))
        }
        .padding()
    }
}
