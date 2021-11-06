//
//  BoxedTextFieldView.swift
//  Beam
//
//  Created by Remi Santos on 30/09/2021.
//

import SwiftUI

struct BoxedTextFieldView: View {
    static var borderColor: BeamColor = BeamColor.combining(lightColor: .Mercury.alpha(0.75), darkColor: .AlphaGray.alpha(0.4))

    var title: String
    @Binding var text: String
    @Binding var isEditing: Bool
    var foregroundColor: BeamColor = BeamColor.Generic.text
    var onCommit: (() -> Void)?
    var onBackspace: (() -> Void)?
    var onEscape: (() -> Void)?
    var onTab: (() -> Bool)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            BeamTextField(text: $text, isEditing: $isEditing, placeholder: title,
                          font: BeamFont.regular(size: 12).nsFont,
                          textColor: foregroundColor.nsColor,
                          placeholderColor: BeamColor.AlphaGray.nsColor,
                          onCommit: { _ in onCommit?() },
                          onEscape: onEscape,
                          onBackspace: onBackspace,
                          onTab: onTab)
                .frame(height: 32)
        }
        .padding(.horizontal, BeamSpacing._80)
        .border(Self.borderColor.swiftUI, width: 1.5)
        .cornerRadius(3.0)
        .contentShape(Rectangle())
        .onTapGesture {
            isEditing = true
        }
        .focusable()
    }
}

struct BoxedTextFieldView_Previews: PreviewProvider {
    static var previews: some View {
        BoxedTextFieldView(title: "The Title", text: .constant("Text content"), isEditing: .constant(false))
            .background(BeamColor.Generic.background.swiftUI)
    }
}
