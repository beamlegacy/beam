//
//  ActionableButton.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

enum ActionableButtonState {
    case normal
    case hovered
    case clicked
    case disabled
}

enum ActionableButtonVariant {
    case primaryBlue
    case primaryPurple
    case secondary
    case custom(ActionableButtonStyle)

    var style: ActionableButtonStyle {
        switch self {
        case .primaryBlue:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: BeamColor.ActionableButtonBlue.foreground.swiftUI,
                                         activeForegroundColor: BeamColor.ActionableButtonBlue.foreground.swiftUI,
                                         disabledForegroundColor: BeamColor.ActionableButtonBlue.disabledForeground.swiftUI,
                                         backgroundColor: BeamColor.ActionableButtonBlue.background.swiftUI,
                                         hoveredBackgroundColor: BeamColor.ActionableButtonBlue.backgroundHovered.swiftUI,
                                         clickedBackgroundColor: BeamColor.ActionableButtonBlue.backgroundClicked.swiftUI,
                                         disabledBackgroundColor: BeamColor.ActionableButtonBlue.backgroundDisabled.swiftUI,
                                         iconName: "editor-format_enter")
        case .primaryPurple:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: BeamColor.ActionableButtonPurple.foreground.swiftUI,
                                         activeForegroundColor: BeamColor.ActionableButtonPurple.foreground.swiftUI,
                                         disabledForegroundColor: BeamColor.ActionableButtonPurple.disabledForeground.swiftUI,
                                         backgroundColor: BeamColor.ActionableButtonPurple.background.swiftUI,
                                         hoveredBackgroundColor: BeamColor.ActionableButtonPurple.backgroundHovered.swiftUI,
                                         clickedBackgroundColor: BeamColor.ActionableButtonPurple.backgroundClicked.swiftUI,
                                         disabledBackgroundColor: BeamColor.ActionableButtonPurple.backgroundDisabled.swiftUI,
                                         iconName: "editor-format_enter")
        case .secondary:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: BeamColor.ActionableButtonSecondary.foreground.swiftUI,
                                         activeForegroundColor: BeamColor.ActionableButtonSecondary.activeForeground.swiftUI,
                                         disabledForegroundColor: BeamColor.ActionableButtonSecondary.disabledForeground.swiftUI,
                                         backgroundColor: BeamColor.ActionableButtonSecondary.background.swiftUI,
                                         hoveredBackgroundColor: BeamColor.ActionableButtonSecondary.backgroundHovered.swiftUI,
                                         clickedBackgroundColor: BeamColor.ActionableButtonSecondary.backgroundClicked.swiftUI,
                                         disabledBackgroundColor: BeamColor.ActionableButtonSecondary.backgroundDisabled.swiftUI,
                                         iconName: "Esc")
        case .custom(let customStyle):
            return ActionableButtonStyle(font: customStyle.font,
                                         foregroundColor: customStyle.foregroundColor,
                                         activeForegroundColor: customStyle.activeForegroundColor,
                                         disabledForegroundColor: customStyle.disabledForegroundColor,
                                         backgroundColor: customStyle.backgroundColor,
                                         hoveredBackgroundColor: customStyle.hoveredBackgroundColor,
                                         clickedBackgroundColor: customStyle.clickedBackgroundColor,
                                         disabledBackgroundColor: customStyle.disabledBackgroundColor,
                                         iconName: customStyle.iconName)
        }
    }
}

struct ActionableButtonStyle {
    var font = BeamFont.medium(size: 13).swiftUI
    var foregroundColor: Color = BeamColor.Button.text.swiftUI
    var activeForegroundColor: Color = BeamColor.Button.activeText.swiftUI
    var disabledForegroundColor: Color
    var backgroundColor: Color
    var hoveredBackgroundColor: Color
    var clickedBackgroundColor: Color = BeamColor.Button.activeBackground.swiftUI
    var disabledBackgroundColor: Color
    let iconName: String
}

struct ActionableButton: View {

    let text: String
    let defaultState: ActionableButtonState
    let variant: ActionableButtonVariant

    let action: (() -> Void)?

    @State private var isHovered = false
    @State private var isTouched = false

    var body: some View {
        HStack(spacing: 20) {
            Text(text)
                .foregroundColor(foregroundColor)
                .padding(.leading, 12)
            Image(variant.style.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(foregroundColor)
                .frame(width: 12, height: 12)
                .padding(.trailing, 12)
        }
        .frame(height: 30)
        .background(backgroundColor)
        .cornerRadius(3.0)
        .animation(.easeInOut(duration: 0.2), value: isTouched)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover(perform: { hovering in
            isHovered = hovering
        })
        .onTouchDown { touching in
            guard defaultState != .disabled else { return }
            isTouched = touching
        }
        .simultaneousGesture(action != nil ?
            TapGesture(count: 1).onEnded {
                action?()
            } : nil
        )
    }

    private var foregroundColor: Color {
        if defaultState == .disabled {
            return variant.style.disabledForegroundColor
        } else if defaultState == .clicked {
            return variant.style.activeForegroundColor
        } else {
            return variant.style.foregroundColor
        }
    }

    private var backgroundColor: Color {
        if defaultState == .disabled {
            return variant.style.disabledBackgroundColor
        } else if defaultState == .clicked || isTouched {
            return variant.style.clickedBackgroundColor
        } else if defaultState == .hovered || isHovered {
            return variant.style.hoveredBackgroundColor
        } else {
            return variant.style.backgroundColor
        }
    }
}

struct ActionableButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HStack {
                VStack {
                    ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryBlue, action: nil)
                    ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryBlue, action: nil)
                    ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryBlue, action: nil)
                    ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryBlue, action: nil)
                }
                VStack {
                    ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryPurple, action: nil)
                    ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryPurple, action: nil)
                    ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryPurple, action: nil)
                    ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryPurple, action: nil)
                }
                VStack {
                    ActionableButton(text: "Secondary Button", defaultState: .normal, variant: .secondary, action: nil)
                    ActionableButton(text: "Secondary Button", defaultState: .hovered, variant: .secondary, action: nil)
                    ActionableButton(text: "Secondary Button", defaultState: .clicked, variant: .secondary, action: nil)
                    ActionableButton(text: "Secondary Button", defaultState: .disabled, variant: .secondary, action: nil)
                }
            }.padding()
            .background(BeamColor.Generic.background.swiftUI)
        }
        if #available(macOS 11.0, *) {
            Group {
                HStack {
                    VStack {
                        ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryBlue, action: nil)
                        ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryBlue, action: nil)
                        ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryBlue, action: nil)
                        ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryBlue, action: nil)
                    }
                    VStack {
                        ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryPurple, action: nil)
                        ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryPurple, action: nil)
                        ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryPurple, action: nil)
                        ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryPurple, action: nil)
                    }
                    VStack {
                        ActionableButton(text: "Secondary Button", defaultState: .normal, variant: .secondary, action: nil)
                        ActionableButton(text: "Secondary Button", defaultState: .hovered, variant: .secondary, action: nil)
                        ActionableButton(text: "Secondary Button", defaultState: .clicked, variant: .secondary, action: nil)
                        ActionableButton(text: "Secondary Button", defaultState: .disabled, variant: .secondary, action: nil)
                    }
                }
                .padding()
                .background(BeamColor.Generic.background.swiftUI)
            }.preferredColorScheme(.dark)
        }
    }
}
