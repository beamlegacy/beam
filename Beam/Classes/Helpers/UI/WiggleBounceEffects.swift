//
//  WiggleBounceEffects.swift
//  Beam
//
//  Created by Remi Santos on 19/05/2021.
//

import SwiftUI

/// Horizontal translation of the view
///
/// Increment animatableData by 1 to trigger a wiggle.
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
    /// Horizontal translation of the view
    ///
    /// Increment animatableData by 1 to trigger a bounce.
    ///
    /// No animation is applied, if you want to animate the wiggle, simply add
    /// `.animation(.default, value: animatableValue)` after this modifier.
    func wiggleEffect(animatableValue: CGFloat, amount: CGFloat = 10, numberOfShakes: Int = 3) -> some View {
        modifier(WiggleEffect(amount: amount, numberOfShakes: numberOfShakes, animatableData: animatableValue))
    }
}

/// Vertical translation of the view
///
/// Increment animatableData by 1 to trigger a bounce.
struct BounceEffect: GeometryEffect {
    var amount: CGFloat = 10
    var numberOfShakes = 3
    // a bounce is triggered everytime animatableData changes
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 0,
                                              y: amount * sin(animatableData * .pi * CGFloat(numberOfShakes))
                                             ))
    }
}

extension View {
    /// Vertical translation of the view
    ///
    /// Increment animatableData by 1 to trigger a bounce.
    ///
    /// No animation is applied, if you want to animate the bounce, simply add
    /// `.animation(.default, value: animatableValue)` after this modifier.
    func bounceEffect(animatableValue: CGFloat, amount: CGFloat = 10, numberOfShakes: Int = 3) -> some View {
        modifier(BounceEffect(amount: amount, numberOfShakes: numberOfShakes, animatableData: animatableValue))
    }
}
