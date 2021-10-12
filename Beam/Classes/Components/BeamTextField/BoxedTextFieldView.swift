//
//  BoxedTextFieldView.swift
//  Beam
//
//  Created by Remi Santos on 30/09/2021.
//

import SwiftUI

struct BoxedTextFieldView: View {
    var title: String
    @Binding var text: String
    var foregroundColor: BeamColor = BeamColor.Generic.text
    var onCommit: (() -> Void)?
    @State private var isEditing: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            BeamTextField(text: $text, isEditing: $isEditing, placeholder: title,
                          font: BeamFont.regular(size: 12).nsFont,
                          textColor: foregroundColor.nsColor,
                          placeholderColor: BeamColor.AlphaGray.nsColor,
                          onCommit: { _ in onCommit?() })
                .frame(height: 32)
        }
        .padding(.horizontal, BeamSpacing._80)
        .border(colorScheme == .dark ? BeamColor.Mercury.swiftUI : BeamColor.Nero.swiftUI, width: 1.5)
        .cornerRadius(3.0)
        .contentShape(Rectangle())
        .onTapGesture {
            isEditing = true
        }
    }
}

struct BoxedTextFieldView_Previews: PreviewProvider {
    static var previews: some View {
        BoxedTextFieldView(title: "The Title", text: .constant("Text content"))
            .background(BeamColor.Generic.background.swiftUI)
    }
}
