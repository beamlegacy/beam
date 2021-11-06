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
                                         foregroundColor: .primaryBlueForeground,
                                         backgroundColor: .primaryBlueBackground,
                                         icon: .init(name: "editor-format_enter"))
        case .primaryPurple:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .primaryPurpleForeground,
                                         backgroundColor: .primaryPurpleBackground,
                                         icon: .init(name: "editor-format_enter"))
        case .secondary:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .secondaryForeground,
                                         backgroundColor: .secondaryBackground,
                                         icon: .init(name: "editor-format_esc", size: 16, palette: .secondaryIcon))
        case .custom(let customStyle):
            return ActionableButtonStyle(font: customStyle.font,
                                         foregroundColor: customStyle.foregroundColor,
                                         backgroundColor: customStyle.backgroundColor,
                                         icon: customStyle.icon)
        }
    }
}

struct ActionableButtonStyle {
    var font = BeamFont.medium(size: 13).swiftUI
    var foregroundColor: ActionableButtonState.Palette
    var backgroundColor: ActionableButtonState.Palette
    var icon: Icon?

    struct Icon {
        let name: String
        var size: CGFloat = 12
        var palette: ActionableButtonState.Palette?
    }
}

struct ActionableButton: View {

    let text: String
    let defaultState: ActionableButtonState
    let variant: ActionableButtonVariant
    var minWidth: CGFloat = 0
    let action: (() -> Void)?

    @State private var isHovered = false
    @State private var isTouched = false

    var body: some View {
        HStack(spacing: 20) {
            Text(text)
                .foregroundColor(foregroundColor)
                .padding(.leading, 12)
            if minWidth > 0 {
                Spacer(minLength: 0)
            }
            if let icon = variant.style.icon {
                Icon(name: icon.name, size: icon.size, color: iconColor)
                    .padding(.trailing, 12)
            }
        }
        .frame(height: 30)
        .if(minWidth > 0) {
            $0.frame(minWidth: minWidth).fixedSize()
        }
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
        let palette = variant.style.foregroundColor
        if defaultState == .disabled {
            return palette.disabled.swiftUI
        } else if defaultState == .clicked {
            return palette.clicked.swiftUI
        } else {
            return palette.normal.swiftUI
        }
    }

    private var backgroundColor: Color {
        let palette = variant.style.backgroundColor
        if defaultState == .disabled {
            return palette.disabled.swiftUI
        } else if defaultState == .clicked || isTouched {
            return palette.clicked.swiftUI
        } else if defaultState == .hovered || isHovered {
            return palette.hovered.swiftUI
        } else {
            return palette.normal.swiftUI
        }
    }

    private var iconColor: Color {
        if let iconPalette = variant.style.icon?.palette {
            if defaultState == .disabled {
                return iconPalette.disabled.swiftUI
            } else if defaultState == .clicked || isTouched {
                return iconPalette.clicked.swiftUI
            } else if defaultState == .hovered || isHovered {
                return iconPalette.hovered.swiftUI
            } else {
                return iconPalette.normal.swiftUI
            }
        }
        return foregroundColor
    }
}

extension ActionableButtonState {
    struct Palette {
        var normal: BeamColor
        var hovered: BeamColor
        var clicked: BeamColor
        var disabled: BeamColor

        static let primaryBlueForeground = ActionableButtonState.Palette(normal: .ActionableButtonBlue.foreground,
                                                                         hovered: .ActionableButtonBlue.foreground,
                                                                         clicked: .ActionableButtonBlue.foreground,
                                                                         disabled: .ActionableButtonBlue.disabledForeground)
        static let primaryBlueBackground = ActionableButtonState.Palette(normal: .ActionableButtonBlue.background,
                                                                         hovered: .ActionableButtonBlue.backgroundHovered,
                                                                         clicked: .ActionableButtonBlue.backgroundClicked,
                                                                         disabled: .ActionableButtonBlue.backgroundDisabled)

        static let primaryPurpleForeground = ActionableButtonState.Palette(normal: .ActionableButtonPurple.foreground,
                                                                           hovered: .ActionableButtonPurple.foreground,
                                                                           clicked: .ActionableButtonPurple.foreground,
                                                                           disabled: .ActionableButtonPurple.disabledForeground)
        static let primaryPurpleBackground = ActionableButtonState.Palette(normal: .ActionableButtonPurple.background,
                                                                           hovered: .ActionableButtonPurple.backgroundHovered,
                                                                           clicked: .ActionableButtonPurple.backgroundClicked,
                                                                           disabled: .ActionableButtonPurple.backgroundDisabled)

        static let secondaryForeground = ActionableButtonState.Palette(normal: .ActionableButtonSecondary.foreground,
                                                                       hovered: .ActionableButtonSecondary.foreground,
                                                                       clicked: .ActionableButtonSecondary.activeForeground,
                                                                       disabled: .ActionableButtonSecondary.disabledForeground)
        static let secondaryBackground = ActionableButtonState.Palette(normal: .ActionableButtonSecondary.background,
                                                                       hovered: .ActionableButtonSecondary.backgroundHovered,
                                                                       clicked: .ActionableButtonSecondary.backgroundClicked,
                                                                       disabled: .ActionableButtonSecondary.backgroundDisabled)

        static let secondaryIcon = ActionableButtonState.Palette(normal: .ActionableButtonSecondary.icon,
                                                                 hovered: .ActionableButtonSecondary.iconHovered,
                                                                 clicked: .ActionableButtonSecondary.iconActive,
                                                                 disabled: .ActionableButtonSecondary.iconDisabled)
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
