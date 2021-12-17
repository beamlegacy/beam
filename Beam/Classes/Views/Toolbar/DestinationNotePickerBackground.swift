//
//  DestinationNotePickerBackground.swift
//  Beam
//
//  Created by Remi Santos on 04/03/2021.
//

import SwiftUI

struct DestinationNotePickerBackground<Content: View>: View {
    var isEditing = false
    var isPressingCharacter = false
    var enableAnimations = true
    var alignment: Alignment = .center

    var content: () -> Content

    @State private var isHoveringBox = false
    private let boxCornerRadius: CGFloat = 6
    private var boxHeight: CGFloat {
        isEditing ? 40 : 32
    }

    private var backgroundColor: Color {
        isEditing ? BeamColor.Autocomplete.focusedBackground.swiftUI : BeamColor.Generic.background.swiftUI
    }
    private var shadowColor: Color {
        guard !isPressingCharacter else { return BeamColor.Autocomplete.focusedPressedShadow.swiftUI }
        return isEditing ? BeamColor.Autocomplete.focusedShadow.swiftUI : BeamColor.Autocomplete.hoveredShadow.swiftUI
    }
    private var shadowOpacity: Double {
        isHoveringBox || isEditing ? 1.0 : 0.0
    }
    private var shadowRadius: CGFloat {
        if isPressingCharacter { return 8 }
        return isEditing ? 3 : 4
    }
    private var shadowOffsetY: CGFloat {
        2
    }
    private var containerAnimation: Animation? {
        guard enableAnimations else { return nil }
        return .easeInOut(duration: animationDuration)
    }
    private var shadowAnimation: Animation? {
        guard enableAnimations else { return nil }
        return isPressingCharacter ?
            .easeInOut(duration: 0.08) :
            .timingCurve(0.25, 0.1, 0.25, 1.0, duration: animationDuration)
    }

    private let animationDuration: Double = 0.3

    var body: some View {
        ZStack(alignment: alignment) {
            RoundedRectangle(cornerRadius: boxCornerRadius)
                .fill(backgroundColor)
                .animation(containerAnimation)
                .shadow(color: shadowColor.opacity(shadowOpacity), radius: shadowRadius, x: 0.0, y: shadowOffsetY)
                .animation(shadowAnimation)
                .onHover(perform: { hovering in
                    isHoveringBox = hovering
                })
            content()
                .cornerRadius(boxCornerRadius)
                .clipped()
        }
    }
}
