//
//  CircledButton.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 28/05/2021.
//

import SwiftUI

struct CircledButton: View {

    struct CircledButtonStyle {
        var horizontalPadding: CGFloat = 6
        var verticalPadding: CGFloat = 3
        var iconSize: CGFloat = 16
        var foregroundColor: Color = BeamColor.Button.text.swiftUI
        var activeForegroundColor: Color = BeamColor.Button.activeText.swiftUI
        var activeBackgroundColor: Color = BeamColor.Button.activeBackground.swiftUI
    }

    var image: String
    var action: () -> Void
    var onHover: ((Bool) -> Void)?
    var style: CircledButtonStyle

    @State private var isHovering = false

    init(image: String, style: CircledButtonStyle = CircledButtonStyle(), action: @escaping () -> Void, onHover: ((Bool) -> Void)? = nil) {
        self.image = image
        self.action = action
        self.style = style
        self.onHover = onHover
    }

    var body: some View {
        Button(action: action, label: {
            Circle()
                .stroke(style.activeBackgroundColor, lineWidth: 1)
                .frame(width: 16, height: 16)
                // Not using Circle() as content shape because onHover ignores it, resulting in some hit areas showing
                // the hover state without being clickable.
                .contentShape(Rectangle())
                .overlay(
                    Image(image)
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .colorMultiply(isHovering ? style.activeForegroundColor : style.foregroundColor)
                )
        })
        .buttonStyle(PlainButtonStyle())
        .onHover { h in
            isHovering = h
            onHover?(h)
        }
    }
}

struct CircledButton_Previews: PreviewProvider {
    static var previews: some View {
        CircledButton(image: "download-resume") {

        }
    }
}
