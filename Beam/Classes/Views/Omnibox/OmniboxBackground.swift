//
//  OmniboxBackground.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

extension Omnibox {

    struct Background<Content: View>: View {
        var isLow = false
        var isPressingCharacter = false
        var alignment: Alignment = .center
        var content: () -> Content

        private let boxCornerRadius: CGFloat = 10
        private let defaultStrokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.3))
        private let lowStrokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.15))
        private let defaultBackgroundColor = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)
        private let lowBackgroundColor = BeamColor.Generic.background

        private let baseShadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.36), darkColor: .From(color: .black, alpha: 0.7))
        private let pulledShadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.07), darkColor: .From(color: .black, alpha: 0.3))

        private var backgroundColor: Color {
            (isLow ? lowBackgroundColor : defaultBackgroundColor).swiftUI
        }
        private var strokeColor: Color {
            (isLow ? lowStrokeColor : defaultStrokeColor).swiftUI
        }
        private var shadowColor: Color {
            (isLow ? pulledShadowColor.alpha(0) : baseShadowColor).swiftUI
        }
        private var shadowRadius: CGFloat {
            (isLow ? 0 : 32) * (isPressingCharacter ? 1/3 : 1.0)
        }
        private var shadowOffsetY: CGFloat {
            (isLow ? 0 : 14) * (isPressingCharacter ? 1/3 : 1.0)
        }

        private let animationDuration: Double = 0.3

        var body: some View {
            ZStack(alignment: alignment) {
                RoundedRectangle(cornerRadius: boxCornerRadius)
                    .stroke(strokeColor, lineWidth: isLow ? 2 : 1) // 1pt centered stroke, makes it a 0.5pt outer stroke.
                RoundedRectangle(cornerRadius: boxCornerRadius)
                    .fill(backgroundColor)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0.0, y: shadowOffsetY)
                content()
                    .cornerRadius(boxCornerRadius)
                    .clipped()
            }
        }
    }
}
