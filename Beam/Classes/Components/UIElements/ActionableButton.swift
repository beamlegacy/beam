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
    case primaryBeam
    case primaryBlue
    case primaryPurple
    case secondary
    case destructive
    case ghost
    case custom(ActionableButtonStyle)

    var style: ActionableButtonStyle {
        switch self {
        case .primaryBeam:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .primaryBeamForeground,
                                         backgroundColor: .primaryBeamBackground,
                                         icon: .init(name: "shortcut-return"))
        case .primaryBlue:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .primaryBlueForeground,
                                         backgroundColor: .primaryBlueBackground,
                                         icon: .init(name: "shortcut-return"))
        case .primaryPurple:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .primaryPurpleForeground,
                                         backgroundColor: .primaryPurpleBackground,
                                         icon: .init(name: "shortcut-return"))
        case .secondary:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .secondaryForeground,
                                         backgroundColor: .secondaryBackground,
                                         icon: .init(name: "shortcut-bttn_esc", size: 16, palette: .secondaryIcon))
        case .destructive:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .destructiveForeground,
                                         backgroundColor: .destructiveBackground,
                                         icon: .init(name: "shortcut-bttn_esc", size: 16, palette: .destructiveBackground))
        case .ghost:
            return ActionableButtonStyle(font: BeamFont.medium(size: 13).swiftUI,
                                         foregroundColor: .ghostForeground,
                                         backgroundColor: .ghostBackground,
                                         icon: .init(name: "shortcut-return"))
        case .custom(let customStyle):
            return customStyle
        }
    }
}

struct ActionableButtonStyle {
    var font = BeamFont.medium(size: 13).swiftUI
    var foregroundColor: ActionableButtonState.Palette
    var backgroundColor: ActionableButtonState.Palette
    var customBackground: ((ActionableButtonState) -> AnyView)?
    var textAlignment = HorizontalAlignment.leading
    var icon: Icon?

    struct Icon {
        let name: String
        var size: CGFloat = 12
        var palette: ActionableButtonState.Palette?
        var alignment = HorizontalAlignment.trailing
        var isTemplate: Bool = true
    }
}

struct ActionableButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    var defaultState: ActionableButtonState = .normal
    let variant: ActionableButtonVariant
    var minWidth: CGFloat = 0
    var maximizeWidth = false
    var height: CGFloat = 30
    var cornerRadius: CGFloat = 4
    var invertBlendMode: Bool = false
    var action: (() -> Void)?

    @State private var isHovered = false
    @State private var isTouched = false

    private let hSpacing: CGFloat = 20
    private let hPadding: CGFloat = 12
    private var hasLeadingIcon: Bool {
        variant.style.icon?.alignment == .leading
    }
    private var hasTrailingIcon: Bool {
        variant.style.icon?.alignment == .trailing
    }
    private var iconTotalSpace: CGFloat {
        // space taken by the icon (with padding and spacing)
        guard let icon = variant.style.icon else { return 0 }
        let iconSize = icon.size
        return iconSize + hSpacing + hPadding
    }
    private var textMinWidth: CGFloat {
        minWidth - iconTotalSpace
    }
    private var textLeadingPadding: CGFloat {
        if variant.style.textAlignment == .center, hasTrailingIcon && minWidth > 0 {
            return iconTotalSpace
        }
        return hasLeadingIcon ? 0 : hPadding
    }
    private var textTrailingPadding: CGFloat {
        if variant.style.textAlignment == .center, hasLeadingIcon && minWidth > 0 {
            return iconTotalSpace
        }
        return hasTrailingIcon ? 0 : hPadding
    }

    var actionableButtonText: some View {
        Text(LocalizedStringKey(text))
            .font(variant.style.font)
            .foregroundColor(foregroundColor)
            .blendModeLightMultiplyDarkScreen(invert: invertBlendMode ? colorScheme == .light : false)
            .if(maximizeWidth) {
                $0.frame(maxWidth: .infinity, alignment: .leading)
            }
    }

    var body: some View {
        HStack(spacing: hSpacing) {
            if let icon = variant.style.icon, icon.alignment == .leading {
                Icon(name: icon.name, width: icon.size, color: iconColor, isTemplate: icon.isTemplate)
                    .blendModeLightMultiplyDarkScreen(invert: invertBlendMode && colorScheme == .light)
                    .padding(.leading, hPadding)
            }

            if let icon = variant.style.icon, icon.alignment == .center {
                HStack(alignment: .center, spacing: 8) {
                    Icon(name: icon.name, width: icon.size, color: iconColor, isTemplate: icon.isTemplate)
                        .blendModeLightMultiplyDarkScreen(invert: invertBlendMode && colorScheme == .light)
                    actionableButtonText
                }.frame(minWidth: minWidth)
            } else {
                actionableButtonText
                    .padding(.leading, textLeadingPadding)
                    .padding(.trailing, textTrailingPadding)
                    .if(minWidth > 0) {
                        $0.frame(minWidth: textMinWidth, alignment: Alignment(horizontal: variant.style.textAlignment, vertical: .center))
                    }
            }
            if let icon = variant.style.icon, icon.alignment == .trailing {
                Icon(name: icon.name, width: icon.size, color: iconColor)
                    .blendModeLightMultiplyDarkScreen(invert: invertBlendMode && colorScheme == .light)
                    .padding(.trailing, hPadding)
            }
        }
        .frame(height: height)
        .background(Group {
            if let color = strokeColor, let lineWidth = strokeLineWidth {
                RoundedRectangle(cornerRadius: cornerRadius).stroke(color, lineWidth: lineWidth)
            }
        })
        .background(customBackground)
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
        .animation(.easeInOut(duration: 0.2), value: isTouched)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover(perform: { hovering in
            isHovered = hovering
        })
        .onTouchDown { touching in
            guard defaultState != .disabled else { return }
            isTouched = touching
        }
        .simultaneousGesture(action != nil && defaultState != .disabled ?
            TapGesture(count: 1).onEnded {
                action?()
            } : nil
        )
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(text)
    }

    private var actualState: ActionableButtonState {
        if defaultState == .disabled {
            return .disabled
        } else if defaultState == .clicked || isTouched {
            return .clicked
        } else if defaultState == .hovered || isHovered {
            return .hovered
        }
        return .normal
    }

    private var customBackground: some View {
        Group {
            variant.style.customBackground?(actualState)
        }
    }

    private var foregroundColor: Color {
        let palette = variant.style.foregroundColor
        switch actualState {
        case .normal:
            return palette.normal.swiftUI
        case .hovered:
            return palette.hovered.swiftUI
        case .clicked:
            return palette.clicked.swiftUI
        case .disabled:
            return palette.disabled.swiftUI
        }
    }

    private var backgroundColor: Color {
        let palette = variant.style.backgroundColor
        switch actualState {
        case .normal:
            return palette.normal.swiftUI
        case .hovered:
            return palette.hovered.swiftUI
        case .clicked:
            return palette.clicked.swiftUI
        case .disabled:
            return palette.disabled.swiftUI
        }
    }

    private var strokeColor: Color? {
        guard let strokePalette = variant.style.backgroundColor.stroke else { return nil }
        switch actualState {
        case .normal:
            return strokePalette.normal?.swiftUI
        case .hovered:
            return strokePalette.hovered?.swiftUI
        case .clicked:
            return strokePalette.clicked?.swiftUI
        case .disabled:
            return strokePalette.disabled?.swiftUI
        }
    }

    private var strokeLineWidth: CGFloat? {
        guard let strokePalette = variant.style.backgroundColor.stroke else { return nil }
        return strokePalette.lineWidth
    }

    private var iconColor: Color {
        if let iconPalette = variant.style.icon?.palette {
            switch actualState {
            case .normal:
                return iconPalette.normal.swiftUI
            case .hovered:
                return iconPalette.hovered.swiftUI
            case .clicked:
                return iconPalette.clicked.swiftUI
            case .disabled:
                return iconPalette.disabled.swiftUI
            }
        }
        return foregroundColor
    }
}

extension ActionableButtonState {
    struct StrokePalette {
        var normal: BeamColor?
        var hovered: BeamColor?
        var clicked: BeamColor?
        var disabled: BeamColor?
        var lineWidth: CGFloat = 2

        static let primaryBeamStroke = ActionableButtonState.StrokePalette(normal: nil, hovered: nil, clicked: nil, disabled: .ActionableButtonBeam.strokeDisabled)
        static let primaryBlueStroke = ActionableButtonState.StrokePalette(normal: nil, hovered: nil, clicked: nil, disabled: .ActionableButtonBeam.strokeDisabled)
        static let primaryPurpleStroke = ActionableButtonState.StrokePalette(normal: nil, hovered: nil, clicked: nil, disabled: .ActionableButtonBeam.strokeDisabled)
        static let ghostStroke = ActionableButtonState.StrokePalette(normal: nil, hovered: nil, clicked: nil, disabled: BeamColor.Generic.background.alpha(0))
    }
    struct Palette {
        var normal: BeamColor
        var hovered: BeamColor
        var clicked: BeamColor
        var disabled: BeamColor
        var stroke: StrokePalette?

        static let primaryBeamForeground = ActionableButtonState.Palette(normal: .ActionableButtonBeam.foreground,
                                                                         hovered: .ActionableButtonBeam.foreground,
                                                                         clicked: .ActionableButtonBeam.foreground,
                                                                         disabled: .ActionableButtonBeam.disabledForeground)
        static let primaryBeamBackground = ActionableButtonState.Palette(normal: .ActionableButtonBeam.background,
                                                                         hovered: .ActionableButtonBeam.backgroundHovered,
                                                                         clicked: .ActionableButtonBeam.backgroundClicked,
                                                                         disabled: .ActionableButtonBeam.backgroundDisabled, stroke: .primaryBeamStroke)

        static let primaryBlueForeground = ActionableButtonState.Palette(normal: .ActionableButtonBlue.foreground,
                                                                         hovered: .ActionableButtonBlue.foreground,
                                                                         clicked: .ActionableButtonBlue.foreground,
                                                                         disabled: .ActionableButtonBlue.disabledForeground)
        static let primaryBlueBackground = ActionableButtonState.Palette(normal: .ActionableButtonBlue.background,
                                                                         hovered: .ActionableButtonBlue.backgroundHovered,
                                                                         clicked: .ActionableButtonBlue.backgroundClicked,
                                                                         disabled: .ActionableButtonBlue.backgroundDisabled, stroke: .primaryBlueStroke)


        static let primaryPurpleForeground = ActionableButtonState.Palette(normal: .ActionableButtonPurple.foreground,
                                                                           hovered: .ActionableButtonPurple.foreground,
                                                                           clicked: .ActionableButtonPurple.foreground,
                                                                           disabled: .ActionableButtonPurple.disabledForeground)
        static let primaryPurpleBackground = ActionableButtonState.Palette(normal: .ActionableButtonPurple.background,
                                                                           hovered: .ActionableButtonPurple.backgroundHovered,
                                                                           clicked: .ActionableButtonPurple.backgroundClicked,
                                                                           disabled: .ActionableButtonPurple.backgroundDisabled, stroke: .primaryPurpleStroke)

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

        static let destructiveForeground = ActionableButtonState.Palette(normal: BeamColor.Shiraz,
                                                                         hovered: BeamColor.Shiraz,
                                                                         clicked: BeamColor.Shiraz,
                                                                         disabled: BeamColor.Shiraz)
        static let destructiveBackground = ActionableButtonState.Palette(normal: BeamColor.Shiraz.alpha(0.1),
                                                                         hovered: BeamColor.Shiraz.alpha(0.1),
                                                                         clicked: BeamColor.Shiraz.alpha(0.3),
                                                                         disabled: BeamColor.Shiraz.alpha(0))

        static let ghostForeground = ActionableButtonState.Palette(normal: BeamColor.Corduroy,
                                                                   hovered: BeamColor.Niobium,
                                                                   clicked: BeamColor.Niobium,
                                                                   disabled: BeamColor.Corduroy)
        static let ghostBackground = ActionableButtonState.Palette(normal: BeamColor.Generic.background.alpha(0),
                                                                   hovered: BeamColor.combining(lightColor: .Mercury, lightAlpha: 1, darkColor: .AlphaGray, darkAlpha: 0.64),
                                                                   clicked: BeamColor.combining(lightColor: .AlphaGray, lightAlpha: 0.6, darkColor: .LightStoneGray, darkAlpha: 0.6),
                                                                   disabled: BeamColor.Generic.background.alpha(0), stroke: .ghostStroke)
    }
}

struct ActionableButton_Previews: PreviewProvider {

    static var centeredVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.primaryPurple.style
        style.textAlignment = .center
        return .custom(style)
    }
    static var noIconCenteredVariant: ActionableButtonVariant {
        var noIconStyle = ActionableButtonVariant.primaryPurple.style
        noIconStyle.icon = nil
        noIconStyle.textAlignment = .center
        return .custom(noIconStyle)
    }
    static var leftIconCenteredVariant: ActionableButtonVariant {
        var style = centeredVariant.style
        var icon = style.icon
        icon?.alignment = .leading
        style.icon = icon
        return .custom(style)
    }
    static var previews: some View {
        Group {
            HStack {
                VStack {
                    ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryBeam)
                    ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryBeam)
                    ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryBeam)
                    ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryBeam)
                }
                VStack {
                    ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryBlue)
                    ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryBlue)
                    ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryBlue)
                    ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryBlue)
                }
                VStack {
                    ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryPurple)
                    ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryPurple)
                    ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryPurple)
                    ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryPurple)
                }
                VStack {
                    ActionableButton(text: "Secondary Button", defaultState: .normal, variant: .secondary)
                    ActionableButton(text: "Secondary Button", defaultState: .hovered, variant: .secondary)
                    ActionableButton(text: "Secondary Button", defaultState: .clicked, variant: .secondary)
                    ActionableButton(text: "Secondary Button", defaultState: .disabled, variant: .secondary)
                }
            }.padding()
            .background(BeamColor.Generic.background.swiftUI)
        }
        Group {
            HStack {
                VStack {
                    ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryBlue)
                    ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryBlue)
                    ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryBlue)
                    ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryBlue)
                }
                VStack {
                    ActionableButton(text: "Primary Button", defaultState: .normal, variant: .primaryPurple)
                    ActionableButton(text: "Primary Button", defaultState: .hovered, variant: .primaryPurple)
                    ActionableButton(text: "Primary Button", defaultState: .clicked, variant: .primaryPurple)
                    ActionableButton(text: "Primary Button", defaultState: .disabled, variant: .primaryPurple)
                }
                VStack {
                    ActionableButton(text: "Secondary Button", defaultState: .normal, variant: .secondary)
                    ActionableButton(text: "Secondary Button", defaultState: .hovered, variant: .secondary)
                    ActionableButton(text: "Secondary Button", defaultState: .clicked, variant: .secondary)
                    ActionableButton(text: "Secondary Button", defaultState: .disabled, variant: .secondary)
                }
            }
            .padding()
            .background(BeamColor.Generic.background.swiftUI)
        }.preferredColorScheme(.dark)

        Group {
            VStack {
                Text("Additional options")
                ActionableButton(text: "Centered Text", defaultState: .normal, variant: centeredVariant)
                ActionableButton(text: "Centered Text No Icon", defaultState: .normal, variant: noIconCenteredVariant)
                Group {
                    Text("Width 300 reference")
                        .font(.caption)
                        .padding(.top)
                        .overlay(
                            Rectangle().fill()
                                .frame(width: 300, height: 1), alignment: .bottom)
                }
                ActionableButton(text: "Min Width 300", defaultState: .normal, variant: .primaryPurple, minWidth: 300)
                ActionableButton(text: "Min Width 300 + Centered", defaultState: .hovered, variant: noIconCenteredVariant, minWidth: 300)
                ActionableButton(text: "With Right Icon", defaultState: .hovered, variant: centeredVariant, minWidth: 300)
                ActionableButton(text: "With Left Icon", defaultState: .hovered, variant: leftIconCenteredVariant, minWidth: 300)
            }
            .padding()
            .background(BeamColor.Generic.background.swiftUI)
        }
    }
}
