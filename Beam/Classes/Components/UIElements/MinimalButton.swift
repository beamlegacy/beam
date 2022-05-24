//
//  MinimalButton.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/05/2022.
//

import SwiftUI

struct MinimalButton: View {
    var customTextView: Text?
    var text: String?
    var hoverUnderline: Bool = false
    var font: Font
    var foregroundColor: Color
    var secondaryColor: Color
    var action: (() -> Void)

    @State private var isHovering: Bool = false

    init(text: String, hoverUnderline: Bool = false, font: Font, foregroundColor: Color, secondaryColor: Color, action: @escaping (() -> Void)) {
        self.text = text
        self.hoverUnderline = hoverUnderline
        self.font = font
        self.foregroundColor = foregroundColor
        self.secondaryColor = secondaryColor
        self.action = action
    }

    init(customTextView: Text, hoverUnderline: Bool = false, font: Font, foregroundColor: Color, secondaryColor: Color, action: @escaping (() -> Void)) {
        self.customTextView = customTextView
        self.hoverUnderline = hoverUnderline
        self.font = font
        self.foregroundColor = foregroundColor
        self.secondaryColor = secondaryColor
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if let customTextView = customTextView {
                    customTextView
                        .if(hoverUnderline, transform: {$0.underline(isHovering, color: secondaryColor)})
                } else {
                    Text(text ?? "")
                        .foregroundColor(isHovering ? secondaryColor : foregroundColor)
                        .if(hoverUnderline, transform: {$0.underline(isHovering, color: secondaryColor)})
                }
            }
            .font(font)
            .foregroundColor(isHovering ? secondaryColor : foregroundColor)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
                isHovering = hovering
            }
        .cursorOverride(.pointingHand)
    }
}

struct MinimalUnderlineButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: BeamSpacing._100) {
            MinimalButton(text: "Simple Button", hoverUnderline: true, font: BeamFont.regular(size: 13).swiftUI, foregroundColor: BeamColor.Generic.text.swiftUI, secondaryColor: BeamColor.Niobium.swiftUI, action: {})

            MinimalButton(text: "Simple Button", font: BeamFont.regular(size: 13).swiftUI, foregroundColor: BeamColor.Generic.text.swiftUI, secondaryColor: BeamColor.Niobium.swiftUI, action: {})
        }
    }
}
