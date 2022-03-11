//
//  FormatterViewBackgroundV2.swift
//  Beam
//
//  Created by Remi Santos on 10/03/2022.
//

import SwiftUI

/// New design for FormatterView background popup implemented progressively
/// Remove the old FormatterViewBackground when every view was updated.
/// Could eventually be merged with OmniboxBackground
///
/// Exemple of ticket for view to update: https://linear.app/beamapp/issue/BE-2670/hyperlink-editor-tweaks
struct FormatterViewBackgroundV2<Content: View>: View {
    var content: () -> Content

    private let boxCornerRadius: CGFloat = 10
    private let strokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.3))
    private let backgroundColor = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)

    private let baseShadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.16), darkColor: .From(color: .black, alpha: 0.7))

    private var shadowColor: Color {
        baseShadowColor.swiftUI
    }
    private var shadowRadius: CGFloat {
        30
    }
    private var shadowOffsetY: CGFloat {
        10
    }

    private let animationDuration: Double = 0.3

    var body: some View {
        ZStack {
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
