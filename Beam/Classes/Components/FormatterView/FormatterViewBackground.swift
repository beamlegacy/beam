//
//  FormatterViewBackground.swift
//  Beam
//
//  Created by Remi Santos on 18/03/2021.
//

import SwiftUI

struct FormatterViewBackground<Content: View>: View {

    var content: () -> Content

    private let boxCornerRadius: CGFloat = 6

    private var backgroundColor: Color {
        BeamColor.Formatter.background.swiftUI
    }
    private var shadowColor: Color {
        BeamColor.Formatter.shadow.swiftUI
    }
    private var shadowRadius: CGFloat {
        13
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
            content()
                .cornerRadius(boxCornerRadius)
                .clipped()
        }
    }
}
