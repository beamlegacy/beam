//
//  AnimatableOffsetEffect.swift
//  Beam
//
//  Created by Remi Santos on 17/06/2021.
//

import SwiftUI

/// Animatable offset transform
private struct OffsetEffect: GeometryEffect {
    var offset: CGSize

    var animatableData: CGSize.AnimatableData {
        get { CGSize.AnimatableData(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(CGAffineTransform(translationX: offset.width, y: offset.height))
    }
}

extension View {
    func animatableOffsetEffect(offset: CGSize) -> some View {
        return modifier(OffsetEffect(offset: offset))
    }
}

extension AnyTransition {
    static func animatableOffset(offset: CGSize) -> AnyTransition {
        .modifier(active: OffsetEffect(offset: offset), identity: OffsetEffect(offset: .zero))
    }
}
