//
//  OmniBarFieldBackground.swift
//  Beam
//
//  Created by Remi Santos on 04/03/2021.
//

import SwiftUI

struct OmniBarFieldBackground<Content: View>: View {
    var isEditing = false
    var enableAnimations = true
    var alignment: Alignment = .center
    var content: () -> Content

    @State private var isHoveringBox = false
    private let boxCornerRadius: CGFloat = 6
    private var boxHeight: CGFloat {
        return isEditing ? 40 : 32
    }

    private var backgroundColor: Color {
        isEditing ? BeamColor.Autocomplete.focusedBackground.swiftUI : BeamColor.Generic.background.swiftUI
    }
    private var shadowColor: Color {
        isEditing ? BeamColor.Autocomplete.focusedShadow.swiftUI : BeamColor.Autocomplete.hoveredShadow.swiftUI
    }
    private var shadowOpacity: Double {
        return isHoveringBox || isEditing ? 1.0 : 0.0
    }
    private var shadowRadius: CGFloat {
        return isEditing ? 12 : 6
    }
    private var shadowOffsetY: CGFloat {
        return isEditing ? 4 : 2
    }
    private let animationDuration = 0.3

    var body: some View {
        ZStack(alignment: alignment) {
            RoundedRectangle(cornerRadius: boxCornerRadius)
                .fill(backgroundColor)
                .animation(enableAnimations ? .timingCurve(0.42, 0.0, 0.58, 1.0, duration: animationDuration) : nil)
                .shadow(color: shadowColor.opacity(shadowOpacity), radius: shadowRadius, x: 0.0, y: shadowOffsetY)
                .animation(enableAnimations ? .timingCurve(0.25, 0.1, 0.25, 1.0, duration: animationDuration) : nil)
                .onHover(perform: { hovering in
                    isHoveringBox = hovering
                })
            content()
                .cornerRadius(boxCornerRadius)
                .clipped()
        }
    }
}
