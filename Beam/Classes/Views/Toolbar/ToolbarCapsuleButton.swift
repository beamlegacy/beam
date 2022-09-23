//
//  ToolbarCapsuleButton.swift
//  Beam
//
//  Created by Remi Santos on 29/11/2021.
//

import SwiftUI

struct ToolbarCapsuleButton<Content: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    var iconName: String?
    var text: String
    var isCompact = false
    var isSelected = false
    var isForeground = false
    var isIncognito = false
    var tabStyle = false
    var hueTint: Double?
    var label: ((_ isHovering: Bool, _ isPressed: Bool) -> Content)?
    var action: (() -> Void)?

    @State var isHovering: Bool = false
    @State var isPressed: Bool = false

    init(isIncognito: Bool = false, isCompact: Bool = false, isSelected: Bool = false, isForeground: Bool = false, tabStyle: Bool = false, hueTint: Double? = nil,
         @ViewBuilder label: @escaping (_ isHovering: Bool, _ isPressed: Bool) -> Content,
         action: (() -> Void)? = nil) {
        self.text = ""
        self.isForeground = isForeground
        self.isCompact = isCompact
        self.isSelected = isSelected
        self.tabStyle = tabStyle
        self.hueTint = hueTint
        self.label = label
        self.action = action
        self.isIncognito = isIncognito
    }

    private var backgroundColor: Color {
        guard isEnabled else { return BeamColor.Nero.swiftUI.opacity(0) }
        if let hueTint = hueTint {
            return Color(hue: hueTint, saturation: 0.4, brightness: 1, opacity: 0.2)
        } else if isPressed {
            return BeamColor.Mercury.swiftUI
        } else if isForeground {
            return BeamColor.ToolBar.capsuleForegroundBackground.swiftUI
        } else if isHovering {
            return BeamColor.Nero.swiftUI.opacity(0.7)
        }
        return .clear
    }

    private var incognitoBackgroundColor: Color {
        guard isIncognito else { return backgroundColor }
        guard isEnabled else { return BeamColor.Nero.swiftUI.opacity(0) }
        if let hueTint = hueTint {
            return Color(hue: hueTint, saturation: 0.4, brightness: 1, opacity: 0.2)
        } else if isPressed {
            return BeamColor.Mercury.inverted(isForeground).swiftUI
        } else if isForeground {
            return BeamColor.ToolBar.capsuleIncognitoForegroundBackground.swiftUI 
        } else if isHovering {
            return BeamColor.Nero.swiftUI.opacity(0.7)
        }
        return .clear
    }

    private var strokeColor: Color {
        guard isEnabled else { return .clear }
        if tabStyle {
            if isForeground, let hueTint = hueTint {
                return Color(hue: hueTint, saturation: 1, brightness: 0.8, opacity: 0.5)
            } else if isPressed {
                return BeamColor.ToolBar.capsuleTabStrokeClicked.swiftUI
            } else if isForeground {
                return BeamColor.ToolBar.capsuleTabForegroundStroke.swiftUI
            } else if isHovering {
                return BeamColor.ToolBar.capsuleStroke.swiftUI
            }
        } else {
            if isPressed {
                return BeamColor.ToolBar.capsuleStrokeClicked.swiftUI
            } else if isForeground || isHovering {
                return BeamColor.ToolBar.capsuleStroke.swiftUI
            }
        }
        return .clear
    }

    private var incognitoStrokeColor: Color {
        guard isIncognito else { return strokeColor }
        guard isEnabled else { return .clear }
        if tabStyle {
            if isForeground, let hueTint = hueTint {
                return Color(hue: hueTint, saturation: 1, brightness: 0.8, opacity: 0.5)
            } else if isPressed {
                return BeamColor.ToolBar.capsuleTabStrokeClicked.swiftUI
            } else if isForeground {
                return BeamColor.ToolBar.capsuleIncognitoTabForegroundStroke.swiftUI
            } else if isHovering {
                return BeamColor.ToolBar.capsuleStroke.swiftUI
            }
        } else {
            if isPressed {
                return BeamColor.ToolBar.capsuleStrokeClicked.swiftUI
            } else if isForeground || isHovering {
                return BeamColor.ToolBar.capsuleStroke.swiftUI
            }
        }
        return .clear
    }

    private var foregroundColor: Color {
        if isHovering || isSelected {
            return BeamColor.Generic.text.swiftUI
        }
        return BeamColor.Corduroy.swiftUI
    }

    private let defaultFont = BeamFont.regular(size: 11).swiftUI
    private let selectedFont = BeamFont.medium(size: 11).swiftUI
    private let minHPadding = BeamSpacing._80

    var body: some View {
        Group {
            if let label = label {
                HStack(spacing: 0) {
                    Spacer(minLength: BeamSpacing._80)
                    label(isHovering, isPressed)
                    Spacer(minLength: BeamSpacing._80)
                }
            } else {
                HStack {
                    if let iconName = iconName {
                        Icon(name: iconName, width: 12, color: foregroundColor)
                            .offset(x: isCompact ? 0 : 4, y: 0)
                    }
                    if !isCompact {
                        Text(text)
                    }
                }.animation(.default, value: isCompact)
            }
        }
        .font(defaultFont)
        .opacity(isSelected ? 0 : 1) // To avoid different width when changing font, we use a shadow text + overlay to maintain layout
        .lineLimit(1)
        .padding(.horizontal, minHPadding)
        .frame(height: 28)
        .overlay(
            isSelected ?
            HStack {
                if let iconName = iconName {
                    Icon(name: iconName, width: 12, color: foregroundColor)
                        .offset(x: isCompact ? 0 : 4, y: 0)
                }
                if !isCompact {
                    Text(text).font(selectedFont)
                }
            }.transition(.opacity)
                .animation(.default, value: isCompact)
            : nil
        )
        .lineLimit(1)
        .foregroundColor(foregroundColor)
        .background(isIncognito ? incognitoBackgroundColor : backgroundColor)
        .cornerRadius(6)
        .padding(0.5)
        .overlay(
            RoundedRectangle(cornerRadius: 6.5)
                .strokeBorder(style: .init(lineWidth: 0.5)).foregroundColor(isIncognito ? incognitoStrokeColor : strokeColor)
        )
        .if(!isForeground || isPressed || colorScheme == .dark) {
            $0.blendModeLightMultiplyDarkScreen()
        }
        .onHover {
            isHovering = $0
            if !$0 {
                isPressed = false
            }
        }
        .onTouchDown { isPressed = $0 }
        .if(action != nil) {
            $0.simultaneousGesture(TapGesture().onEnded {
                action?()
            })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(text)
    }
}

extension ToolbarCapsuleButton where Content == EmptyView {
    init(iconName: String? = nil, text: String, isCompact: Bool = false, isSelected: Bool = false, isForeground: Bool = false, tabStyle: Bool = false,
         action: (() -> Void)? = nil) {
        self.iconName = iconName
        self.text = text
        self.isCompact = isCompact
        self.isSelected = isSelected
        self.isForeground = isForeground
        self.tabStyle = tabStyle
        self.action = action
        self.label = nil
    }
}

private extension ToolbarCapsuleButton where Content == EmptyView {

    /// init for previews
    init(iconName: String? = nil, text: String, isSelected: Bool = false, isHovering: Bool = false, isPressed: Bool = false) {
        self.iconName = iconName
        self.text = text
        self.isSelected = isSelected
        self._isHovering = State(initialValue: isHovering)
        self._isPressed = State(initialValue: isPressed)
        self.action = nil
        self.label = nil
    }
}

private extension ToolbarCapsuleButton {

    /// init for previews
    init(isHovering: Bool = false, isPressed: Bool = false, @ViewBuilder label: @escaping (_ isHovering: Bool, _ isPressed: Bool) -> Content) {
        self.text = ""
        self.isSelected = false
        self._isHovering = State(initialValue: isHovering)
        self._isPressed = State(initialValue: isPressed)
        self.action = nil
        self.label = label
    }
}

struct ToolbarCapsuleButton_Previews: PreviewProvider {

    static var customLabel: some View {
        Rectangle()
            .fill(Color.red)
            .frame(width: 100, height: 10)
    }
    static var previews: some View {
        Group {
            HStack {
                VStack {
                    ToolbarCapsuleButton(text: "Note 1", isHovering: false)
                    ToolbarCapsuleButton(text: "Note 1", isHovering: true)
                    ToolbarCapsuleButton(text: "Note 1", isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack {
                    ToolbarCapsuleButton(text: "Note 1", isSelected: true, isHovering: false)
                    ToolbarCapsuleButton(text: "Note 1", isSelected: true, isHovering: true)
                    ToolbarCapsuleButton(text: "Note 1", isSelected: true, isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding()
        }
        .background(Color.white)
        Group {
            HStack {
                VStack {
                    ToolbarCapsuleButton(text: "Note 1", isHovering: false)
                    ToolbarCapsuleButton(text: "Note 1", isHovering: true)
                    ToolbarCapsuleButton(text: "Note 1", isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack {
                    ToolbarCapsuleButton(text: "Note 1", isSelected: true, isHovering: false)
                    ToolbarCapsuleButton(text: "Note 1", isSelected: true, isHovering: true)
                    ToolbarCapsuleButton(text: "Note 1", isSelected: true, isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .background(Color.black)

        Group {
            VStack {
                Text("Custom content")
                ToolbarCapsuleButton(isHovering: false) { _, _ in
                    customLabel
                }
                ToolbarCapsuleButton(isHovering: true) { isHovering, _ in
                    customLabel
                        .overlay(Text("isHovering: \(isHovering ? "yes" : "no")").font(.caption).opacity(0.6))
                }
                ToolbarCapsuleButton(isHovering: true, isPressed: true) { _, isPressed in
                    customLabel
                        .overlay(Text("isPressed: \(isPressed ? "yes" : "no")").font(.caption).opacity(0.6))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding()
        }
    }
}
