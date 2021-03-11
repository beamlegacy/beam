//
//  OmniBarButton.swift
//  Beam
//
//  Created by Remi Santos on 04/03/2021.
//

import SwiftUI

struct OmniBarButton: View {
    var icon: String
    var accessibilityId: String
    var action: () -> Void
    var size: CGFloat?
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State private var isHovering: Bool = false

    private let disabledContentColor = Color(.toolbarButtonIconDisabledColor)
    private let contentColor = Color(.toolbarButtonIconColor)
    private let activeContentColor = Color(.toolbarButtonActiveIconColor)

    var foregroundColor: Color {
        guard isEnabled else { return disabledContentColor }
        return isHovering ? activeContentColor : contentColor
    }

    var body: some View {
        Button(action: action) {
            Icon(name: icon, size: 20, color: foregroundColor)
        }
        .accessibility(identifier: accessibilityId)
        .buttonStyle(RoundRectButtonStyle(size: size))
        .onHover { h in
            self.isHovering = h
        }
    }
}

struct OmniBarButton_Previews: PreviewProvider {
    static var previews: some View {
        OmniBarButton(icon: "nav-journal", accessibilityId: "axID") {}
            .frame(width: 26, height: 26)
            .frame(width: 40, height: 40)
            .background(Color.white)
    }
}
