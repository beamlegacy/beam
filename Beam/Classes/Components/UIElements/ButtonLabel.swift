//
//  ButtonLabel.swift
//  Beam
//
//  Created by Remi Santos on 25/03/2021.
//

import SwiftUI

enum ButtonLabelState {
    case normal
    case active
    case hovered
    case clicked
    case disabled
}

enum ButtonLabelVariant {
    case primary
    case secondary
    case dropdown
}

struct ButtonLabelStyle {
    var font = BeamFont.regular(size: 12).swiftUI
    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 3
    var iconSize: CGFloat = 16
    var spacing: CGFloat = 2
    var foregroundColor: Color = BeamColor.Button.text.swiftUI
    var activeForegroundColor: Color = BeamColor.Button.activeText.swiftUI
    var backgroundColor: Color?
    var hoveredBackgroundColor: Color?
    var activeBackgroundColor: Color = BeamColor.Button.activeBackground.swiftUI
    var disableAnimations = true // Should be replaced by the parent view disabling animations with .animation(nil) when needed.
    var backgroundCornerRadius: CGFloat = 4
    var leadingPaddingAdjustment: CGFloat = 0
}

struct ButtonLabel: View {
    var text: String?
    var iconName: String?
    var lottieName: String?
    let defaultState: ButtonLabelState
    let variant: ButtonLabelVariant
    // TODO replace style by a custom modifier like .buttonLabelStyle()
    let style: ButtonLabelStyle

    let action: (() -> Void)?

    private var customView: ((_ hovered: Bool, _ clicked: Bool) -> AnyView)?

    @State private var isHovering = false
    @State private var isTouching = false

    init(_ text: String? = nil, icon: String? = nil, state: ButtonLabelState = .normal, variant: ButtonLabelVariant = .secondary,
         customStyle: ButtonLabelStyle = ButtonLabelStyle(), action: (() -> Void)? = nil) {
        self.text = text
        self.iconName = icon
        self.defaultState = state
        self.variant = variant
        self.style = customStyle
        self.action = action
    }

    init(_ text: String? = nil, lottie: String, state: ButtonLabelState = .normal, variant: ButtonLabelVariant = .secondary,
         customStyle: ButtonLabelStyle = ButtonLabelStyle(), action: (() -> Void)? = nil) {
        self.text = text
        self.lottieName = lottie
        self.defaultState = state
        self.variant = variant
        self.style = customStyle
        self.action = action
    }

    init(@ViewBuilder customView: @escaping (_ hovered: Bool, _ clicked: Bool) -> AnyView,
         state: ButtonLabelState = .normal, variant: ButtonLabelVariant = .secondary,
         customStyle: ButtonLabelStyle = ButtonLabelStyle(), action: (() -> Void)? = nil) {
        self.customView = customView
        self.defaultState = state
        self.variant = variant
        self.style = customStyle
        self.action = action
    }

    private var foregroundColor: Color {
        if defaultState == .disabled {
            return style.foregroundColor.opacity(0.35)
        } else if isHovering || isTouching || defaultState != .normal {
            return style.activeForegroundColor
        }
        return style.foregroundColor
    }

    private var foregroundNSColor: NSColor {
        NSColor(foregroundColor)
    }

    private var backgroundColor: Color? {
        if isTouching || defaultState == .clicked {
            return style.activeBackgroundColor
        } else if isHovering || defaultState == .hovered {
            return style.hoveredBackgroundColor
        }
        return style.backgroundColor
    }

    var body: some View {
        HStack(spacing: style.spacing) {
            if let customViewBuilder = customView {
                customViewBuilder(isHovering, isTouching)
            } else {
                if let icon = iconName {
                    Icon(name: icon, width: style.iconSize, color: foregroundColor)
                }
                if let lottie = lottieName {
                    LottieView(name: lottie, playing: true, color: foregroundNSColor, animationSize: CGSize(width: style.iconSize, height: style.iconSize))
                }
                if let text = text {
                    Text(text)
                        .foregroundColor(foregroundColor)
                        .font(style.font)
                        .underline(variant == .primary, color: foregroundColor)
                }
                if variant == .dropdown {
                    Icon(name: "editor-breadcrumb_down", width: 8, color: foregroundColor)
                }
            }
        }
        .padding(.leading, style.horizontalPadding - style.leadingPaddingAdjustment)
        .padding(.trailing, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(backgroundColor)
        .if(style.disableAnimations) {
            $0.animation(nil)
        }
        .cornerRadius(style.backgroundCornerRadius)
        .onHover { hovering in
            guard defaultState != .disabled else { return }
            isHovering = hovering
        }
        .onTouchDown { touching in
            guard defaultState != .disabled else { return }
            isTouching = touching
        }
        .simultaneousGesture(action != nil ?
            TapGesture(count: 1).onEnded {
                action?()
            } : nil
        )
    }
}

struct ButtonLabel_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            VStack {
                ButtonLabel("Primary Button", variant: .primary)
                ButtonLabel("Primary Button", state: .active, variant: .primary)
                ButtonLabel("Primary Button", state: .hovered, variant: .primary)
                ButtonLabel("Primary Button", state: .clicked, variant: .primary)
                ButtonLabel("Primary Button", state: .disabled, variant: .primary)
            }
            VStack {
                ButtonLabel("Secondary Button")
                ButtonLabel("Secondary Button", state: .active)
                ButtonLabel("Secondary Button", state: .hovered)
                ButtonLabel("Secondary Button", state: .clicked)
                ButtonLabel("Secondary Button", state: .disabled)
            }
        }
        .padding()
        .background(Color.white)
    }
}

extension ButtonLabelStyle {
    static let tinyIconStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle()
        style.iconSize = 16
        style.verticalPadding = 0
        style.horizontalPadding = 0
        style.foregroundColor = BeamColor.LightStoneGray.swiftUI
        style.activeForegroundColor = BeamColor.Niobium.swiftUI
        style.hoveredBackgroundColor = BeamColor.Mercury.swiftUI
        style.activeBackgroundColor = BeamColor.AlphaGray.swiftUI
        return style
    }()
}
