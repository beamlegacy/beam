//
//  OmniboxV2BoxBackground.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

extension OmniboxV2Box {

    struct Background<Content: View>: View {
        var isPulled = false
        var alignment: Alignment = .center
        var content: () -> Content

        private let boxCornerRadius: CGFloat = 10
        private let strokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.3))
        private let backgroundColor = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)

        private let baseShadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.32), darkColor: .From(color: .black, alpha: 0.7))
        private let pulledShadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.07), darkColor: .From(color: .black, alpha: 0.3))

        private var shadowColor: Color {
            (isPulled ? pulledShadowColor : baseShadowColor).swiftUI
        }
        private var shadowRadius: CGFloat {
            isPulled ? 20 : 60
        }
        private var shadowOffsetY: CGFloat {
            isPulled ? 4 : 24
        }

        private let animationDuration: Double = 0.3

        var body: some View {
            ZStack(alignment: alignment) {
                RoundedRectangle(cornerRadius: boxCornerRadius)
                    .stroke(strokeColor.swiftUI, lineWidth: 1) // 1pt centered stroke, makes it a 0.5pt outer stroke.
                RoundedRectangle(cornerRadius: boxCornerRadius)
                    .fill(backgroundColor.swiftUI)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0.0, y: shadowOffsetY)
                content()
                    .cornerRadius(boxCornerRadius)
                    .clipped()
            }
        }
    }
}
