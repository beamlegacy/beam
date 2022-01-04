//
//  WebFieldAutofillButton.swift
//  Beam
//
//  Created by Frank Lefebvre on 13/12/2021.
//

import SwiftUI

struct WebFieldAutofillButton: View {
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                backgroundColor
                    .blendMode(colorScheme == .light ? .multiply : .screen)
                    .frame(width: 24, height: 24)
                    .cornerRadius(3)
                Image("autofill-password")
                    .renderingMode(.template)
                    .foregroundColor(isHovering ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)
                    .blendMode(colorScheme == .light ? .multiply : .screen)
            }
            .onHover { isHovering = $0 }
        }
        .buttonStyle(.borderless)
    }

    var backgroundColor: Color {
        guard isHovering else { return .clear }
        return BeamColor.Mercury.swiftUI
    }
}

struct WebFieldAutofillButton_Previews: PreviewProvider {
    static var previews: some View {
        WebFieldAutofillButton {}
    }
}
