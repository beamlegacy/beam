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

    private let defaultFont = BeamFont.regular(size: 11).swiftUI
    private let selectedFont = BeamFont.medium(size: 11).swiftUI
    private let minHPadding = BeamSpacing._80

    var body: some View {
        Text(text)
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
