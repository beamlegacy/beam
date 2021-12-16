//
//  OmniboxV2CapsuleButton.swift
//  Beam
//
//  Created by Remi Santos on 29/11/2021.
//

import SwiftUI

struct OmniboxV2CapsuleButton<Content: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    var text: String
    var isSelected = false
    var isForeground = false
    var label: ((_ isHovering: Bool, _ isPressed: Bool) -> Content)?
    var action: (() -> Void)?

    @State var isHovering: Bool = false
    @State var isPressed: Bool = false

    init(isSelected: Bool = false, isForeground: Bool = false,
         @ViewBuilder label: @escaping (_ isHovering: Bool, _ isPressed: Bool) -> Content,
         action: (() -> Void)? = nil) {
        self.text = ""
        self.isForeground = isForeground
        self.isSelected = isSelected
        self.label = label
        self.action = action
    }

    private var backgroundColor: Color {
        guard isEnabled else { return .clear }
        if isPressed {
            return BeamColor.Mercury.swiftUI
        } else if isForeground {
            return BeamColor.ToolBar.capsuleForegroundBackgrond.swiftUI
        } else if isHovering {
            return BeamColor.Nero.swiftUI.opacity(0.7)
        }
        return .clear
    }

    private var strokeColor: Color {
        guard isEnabled else { return .clear }
        if isPressed {
            return BeamColor.ToolBar.capsuleStrokeClicked.swiftUI
        } else if isForeground || isHovering {
            return BeamColor.ToolBar.capsuleStroke.swiftUI
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
                Text(text)
            }
        }
        .font(defaultFont)
        .opacity(isSelected ? 0 : 1) // To avoid different width when changing font, we use a shadow text + overlay to maintain layout
        .lineLimit(1)
        .padding(.horizontal, minHPadding)
        .frame(height: 28)
        .overlay(
            isSelected ? Text(text).font(selectedFont).lineLimit(1).padding(.horizontal, minHPadding - 1) : nil
        )
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .cornerRadius(6)
        .padding(0.5)
        .overlay(
            RoundedRectangle(cornerRadius: 6.5)
                .strokeBorder(style: .init(lineWidth: 0.5)).foregroundColor(strokeColor)
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
    }
}

extension OmniboxV2CapsuleButton where Content == EmptyView {
    init(text: String, isSelected: Bool = false, isForeground: Bool = false, action: (() -> Void)? = nil) {
        self.text = text
        self.isSelected = isSelected
        self.isForeground = isForeground
        self.action = action
        self.label = nil
    }
}

private extension OmniboxV2CapsuleButton where Content == EmptyView {

    /// init for previews
    init(text: String, isSelected: Bool = false, isHovering: Bool = false, isPressed: Bool = false) {
        self.text = text
        self.isSelected = isSelected
        self._isHovering = State(initialValue: isHovering)
        self._isPressed = State(initialValue: isPressed)
        self.action = nil
        self.label = nil
    }
}

private extension OmniboxV2CapsuleButton {

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

struct OmniboxV2CapsuleButton_Previews: PreviewProvider {

    static var customLabel: some View {
        Rectangle()
            .fill(Color.red)
            .frame(width: 100, height: 10)
    }
    static var previews: some View {
        Group {
            HStack {
                VStack {
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: false)
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack {
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: false)
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding()
        }
        .background(Color.white)
        Group {
            HStack {
                VStack {
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: false)
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack {
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: false)
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: true, isPressed: true)
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
                OmniboxV2CapsuleButton(isHovering: false) { _, _ in
                    customLabel
                }
                OmniboxV2CapsuleButton(isHovering: true) { isHovering, _ in
                    customLabel
                        .overlay(Text("isHovering: \(isHovering ? "yes" : "no")").font(.caption).opacity(0.6))
                }
                OmniboxV2CapsuleButton(isHovering: true, isPressed: true) { _, isPressed in
                    customLabel
                        .overlay(Text("isPressed: \(isPressed ? "yes" : "no")").font(.caption).opacity(0.6))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding()
        }
    }
}
