//
//  PointAndShootOffsetWithAnimation.swift
//  Beam
//
//  Created by Stef Kors on 13/08/2021.
//

import SwiftUI

struct PointAndShootOffsetWithAnimationView: ViewModifier {
    var offset: NSPoint
    var animation: Animation

    func body(content: Content) -> some View {
        content
            .animation(nil)
            .scaleEffect(1)
            .offset(x: offset.x, y: offset.y)
            .animation(animation, value: offset)
    }

}

extension View {
    /// Animate offset values without leaking the animation transitions to other UI properties like `.position(x, y)`
    /// - Parameters:
    ///   - x: X Coordinate
    ///   - y: Y Coordinate
    ///   - animation: animation to apply, defaults to .default
    /// - Returns: animated content
    func pointAndShootOffsetWithAnimation(_ x: CGFloat = 0, _ y: CGFloat = 0, animation: Animation = .default) -> some View {
        return modifier(PointAndShootOffsetWithAnimationView(offset: NSPoint(x: x, y: y), animation: animation))
    }
    /// Animate offset values without leaking the animation transitions to other UI properties like `.position(x, y)`
    /// - Parameters:
    ///   - x: X Coordinate
    ///   - y: Y Coordinate
    ///   - animation: animation to apply, defaults to `.default`
    /// - Returns: animated content
    func pointAndShootOffsetWithAnimation(x: CGFloat = 0, y: CGFloat = 0, animation: Animation = .default) -> some View {
        return modifier(PointAndShootOffsetWithAnimationView(offset: NSPoint(x: x, y: y), animation: animation))
    }
    /// Animate offset values without leaking the animation transitions to other UI properties like `.position(x, y)`
    /// - Parameters:
    ///   - offset: X, Y Coordinates
    ///   - animation: animation to apply, defaults to `.default`
    /// - Returns: animated content
    func pointAndShootOffsetWithAnimation(_ offset: NSPoint, animation: Animation = .default) -> some View {
        return modifier(PointAndShootOffsetWithAnimationView(offset: offset, animation: animation))
    }
}
