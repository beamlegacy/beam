//
//  WiggleEffect.swift
//  Beam
//
//  Created by Remi Santos on 19/05/2021.
//

import SwiftUI

struct WiggleEffect: GeometryEffect {
    var amount: CGFloat = 10
    var numberOfShakes = 3
    // a wiggle is triggered everytime animatableData changes
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(numberOfShakes)),
            y: 0))
    }
}

extension View {
    func wiggleEffect(animatableValue: CGFloat) -> some View {
        return modifier(WiggleEffect(animatableData: animatableValue))
    }
}
