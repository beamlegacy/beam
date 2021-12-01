//
//  OmniboxV2CapsuleButton.swift
//  Beam
//
//  Created by Remi Santos on 29/11/2021.
//

import SwiftUI

struct OmniboxV2CapsuleButton: View {
    var text: String
    var isSelected = false
    var action: (() -> Void)?

    @State var isHovering = false
    @State var isPressed = false

    private var backgroundColor: Color {
        if isPressed {
            return BeamColor.Mercury.swiftUI
        } else if isHovering {
            return BeamColor.Mercury.swiftUI.opacity(0.7)
        }
        return .clear
    }

    private var strokeColor: Color {
        if isPressed {
            return BeamColor.ToolBar.capsuleStrokeClicked.swiftUI
        } else if isHovering {
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

    private var font: Font {
        if isSelected {
            return BeamFont.medium(size: 11).swiftUI
        }
        return BeamFont.regular(size: 11).swiftUI
    }

    var body: some View {
        ZStack {
            backgroundColor
                .cornerRadius(6)
            HStack(spacing: 0) {
                Spacer(minLength: BeamSpacing._80)
                Text(text)
                    .lineLimit(1)
                    .font(font)
                    .foregroundColor(foregroundColor)
                Spacer(minLength: BeamSpacing._80)
            }
        }
        .frame(height: 28)
        .cornerRadius(6)
        .padding(0.5)
        .overlay(
            RoundedRectangle(cornerRadius: 6.5)
                .strokeBorder(style: .init(lineWidth: 0.5)).foregroundColor(strokeColor)
        )
        .blendModeLightMultiplyDarkScreen()
        .onHover { isHovering = $0 }
        .onTouchDown { isPressed = $0 }
        .simultaneousGesture(TapGesture().onEnded {
            action?()
        })
    }
}

struct OmniboxV2CapsuleButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HStack {
                VStack {
                    OmniboxV2CapsuleButton(text: "Card 1")
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack {
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true)
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
                    OmniboxV2CapsuleButton(text: "Card 1")
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack {
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: true)
                    OmniboxV2CapsuleButton(text: "Card 1", isSelected: true, isHovering: true, isPressed: true)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .background(Color.black)
    }
}
