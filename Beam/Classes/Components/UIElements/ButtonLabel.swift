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
    var font = BeamFont.medium(size: 12).swiftUI
    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 3
}

struct ButtonLabel: View {
    let text: String?
    let iconName: String?
    let defaultState: ButtonLabelState
    let variant: ButtonLabelVariant
    let style: ButtonLabelStyle
    let action: (() -> Void)?

    @State private var isHovering = false
    @State private var isTouching = false

    init(_ text: String? = nil, icon: String? = nil, state: ButtonLabelState = .normal, variant: ButtonLabelVariant = .secondary, customStyle: ButtonLabelStyle = ButtonLabelStyle(), action: (() -> Void)? = nil) {
        self.text = text
        self.iconName = icon
        self.defaultState = state
        self.variant = variant
        self.style = customStyle
        self.action = action
    }

    private var foregroundColor: Color {
        guard defaultState != .disabled else {
            return BeamColor.Button.text.swiftUI.opacity(0.35)
        }
        guard isHovering || isTouching || defaultState != .normal else {
            return BeamColor.Button.text.swiftUI
        }
        return BeamColor.Button.activeText.swiftUI
    }

    private var backgroundColor: Color? {
        if isTouching || defaultState == .clicked {
            return BeamColor.Button.activeBackground.swiftUI
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 2) {
            if let icon = iconName {
                Icon(name: icon, size: 16, color: foregroundColor)
            }
            if let text = text {
                Text(text)
                    .foregroundColor(foregroundColor)
                    .font(style.font)
                    .underline(variant == .primary, color: foregroundColor)
            }
            if variant == .dropdown {
                Icon(name: "editor-breadcrumb_down", size: 8, color: foregroundColor)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(backgroundColor)
        .animation(nil)
        .cornerRadius(3)
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
