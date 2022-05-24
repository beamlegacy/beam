//
//  SidebarListBackground.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 20/05/2022.
//

import SwiftUI

struct SidebarListBackground: View {

    let isSelected: Bool
    let isHovering: Bool
    let isPressed: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
                        .foregroundColor(cellBackground)
                        .blendModeLightMultiplyDarkScreen()
                        .animation(nil)
    }

    private var cellBackground: Color {
        if isSelected && isPressed {
            return BeamColor.Mercury.swiftUI
        } else if isSelected && isHovering {
            return BeamColor.Mercury.alpha(lightScheme ? 0.8 : 0.6).swiftUI
        } else if isSelected {
            return BeamColor.Mercury.alpha(lightScheme ? 0.6 : 0.4).swiftUI
        } else if isPressed {
            return BeamColor.Mercury.alpha(lightScheme ? 0.6 : 0.4).swiftUI
        } else if isHovering {
            return BeamColor.Mercury.alpha(lightScheme ? 0.35 : 0.24).swiftUI
        } else {
            return .clear
        }
    }

    private var lightScheme: Bool {
        colorScheme == .light
    }
}

struct SidebarListBackground_Previews: PreviewProvider {
    static var previews: some View {
        SidebarListBackground(isSelected: true, isHovering: true, isPressed: true)
    }
}
