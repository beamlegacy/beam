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

extension View {

    func formatterViewBackgroundAnimation(with viewModel: BaseFormatterViewViewModel) -> some View {
        self.animation(.easeInOut(duration: 0.15))
            .scaleEffect(viewModel.visible ? 1.0 : 0.98)
            .offset(x: 0, y: viewModel.visible ? 0.0 :
                        (viewModel.animationDirection == .bottom ? -4.0 : 4.0)
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.6))
            .opacity(viewModel.visible ? 1.0 : 0.0)
            .animation(viewModel.visible ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.15))
    }
}
