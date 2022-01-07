//
//  WebFieldAutofillButton.swift
//  Beam
//
//  Created by Frank Lefebvre on 13/12/2021.
//

import SwiftUI

struct WebFieldAutofillButton: View {
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                backgroundColor
                    .frame(width: 24, height: 24)
                    .cornerRadius(3)
                Image("autofill-password")
                    .renderingMode(.template)
                    .foregroundColor(isHovering ? BeamColor.WebFieldAutofill.fieldButtonIconHovered.swiftUI : BeamColor.WebFieldAutofill.fieldButtonIcon.swiftUI)
            }
            .onHover { isHovering = $0 }
        }
        .buttonStyle(.borderless)
        .environment(\.colorScheme, .light)
    }

    var backgroundColor: Color {
        isHovering ? BeamColor.WebFieldAutofill.fieldButtonBackgroundHovered.swiftUI : .clear
    }
}

struct WebFieldAutofillButton_Previews: PreviewProvider {
    static var previews: some View {
        WebFieldAutofillButton {}
    }
}
