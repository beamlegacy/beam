//
//  FormatterViewBackground.swift
//  Beam
//
//  Created by Remi Santos on 18/03/2021.
//

import SwiftUI

struct FormatterViewBackground<Content: View>: View {

    var shadowOpacity: Double? = 1
    var content: (() -> Content)?

    private let boxCornerRadius: CGFloat = 6

    private var backgroundColor: Color {
        BeamColor.Formatter.background.swiftUI
    }
    private var shadowColor: Color {
        let color = BeamColor.Formatter.shadow.swiftUI
        guard let shadowOpacity = shadowOpacity, shadowOpacity < 1.0 else { return color }
        return color.opacity(shadowOpacity)
    }
    private var shadowRadius: CGFloat {
        15
    }
    private var shadowOffsetY: CGFloat {
        7
    }
    private let animationDuration = 0.3

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: boxCornerRadius)
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: shadowRadius, x: 0.0, y: shadowOffsetY)
            content?()
                .cornerRadius(boxCornerRadius)
                .clipped()
        }
        .onTapGesture { /* stop any click propagation */ }
    }
}
