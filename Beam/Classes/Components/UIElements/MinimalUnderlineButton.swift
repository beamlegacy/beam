//
//  MinimalUnderlineButton.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/05/2022.
//

import SwiftUI

struct MinimalUnderlineButton: View {
    var customTextView: Text?
    var text: String?
    var font: Font
    var foregroundColor: Color
    var action: (() -> Void)

    @State private var isHovering: Bool = false

    init(text: String, font: Font, foregroundColor: Color, action: @escaping (() -> Void)) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.action = action
    }

    init(customTextView: Text, font: Font, foregroundColor: Color, action: @escaping (() -> Void)) {
        self.customTextView = customTextView
        self.font = font
        self.foregroundColor = foregroundColor
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if let customTextView = customTextView {
                    customTextView
                        .underline(isHovering, color: foregroundColor)

                } else {
                    Text(text ?? "")
                        .underline(isHovering, color: foregroundColor)
                }
            }.font(font)
                .foregroundColor(foregroundColor)
        }.buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct MinimalUnderlineButton_Previews: PreviewProvider {
    static var previews: some View {
        MinimalUnderlineButton(text: "Simple Button", font: BeamFont.regular(size: 13).swiftUI, foregroundColor: BeamColor.Generic.text.swiftUI, action: {})
    }
}
