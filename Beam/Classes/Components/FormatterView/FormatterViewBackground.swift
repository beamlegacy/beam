//
//  FormatterViewBackground.swift
//  Beam
//
//  Created by Remi Santos on 18/03/2021.
//

import SwiftUI

struct FormatterViewBackground<Content: View>: View {

    var boxCornerRadius: CGFloat = 6
    var shadowOpacity: Double? = 1
    var content: (() -> Content)?

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
        self
            .animation(BeamAnimation.easeInOut(duration: 0.15), value: viewModel.visible)
            .scaleEffect(viewModel.visible ? 1.0 : 0.98)
            .offset(x: 0, y: viewModel.visible ? 0.0 :
                        (viewModel.animationDirection == .bottom ? -4.0 : 4.0)
            )
            .animation(BeamAnimation.easeInOut(duration: 0.2), value: viewModel.visible)
            .opacity(viewModel.visible ? 1.0 : 0.0)
            .animation(viewModel.visible ? BeamAnimation.easeInOut(duration: 0.3) : BeamAnimation.easeInOut(duration: 0.15),
                       value: viewModel.visible)
    }
}
