//
//  TabContentIcon.swift
//  Beam
//
//  Created by Remi Santos on 22/02/2022.
//

import SwiftUI

extension TabView {
    struct TabContentIcon: View {
        var name: String
        var width: CGFloat = 16
        var color = BeamColor.AlphaGray
        var hoveredColor = BeamColor.Corduroy
        var pressedColor = BeamColor.Niobium
        var action: (() -> Void)?

        @State private var isHovering = false
        @State private var isPressed = false

        private var foregroundColor: Color {
            if isPressed {
                return pressedColor.swiftUI
            } else if isHovering {
                return hoveredColor.swiftUI
            }
            return color.swiftUI
        }
        var body: some View {
            Icon(name: name, width: width, color: foregroundColor)
                .onHover { isHovering = $0 }
                .onTouchDown { isPressed = $0 }
                .simultaneousGesture(TapGesture().onEnded {
                    action?()
                })
        }
    }

    struct TabContentLottieIcon: View {
        var name: String
        var playing: Bool
        var width: CGFloat = 16
        var color = BeamColor.AlphaGray
        var hoveredColor = BeamColor.Corduroy
        var pressedColor = BeamColor.Niobium
        var action: (() -> Void)?
        var onAnimationCompleted: () -> Void

        @State private var isHovering = false
        @State private var isPressed = false

        private var foregroundColor: NSColor {
            if isPressed {
                return pressedColor.nsColor
            } else if isHovering {
                return hoveredColor.nsColor
            }
            return color.nsColor
        }
        var body: some View {
            LottieView(name: name,
                       playing: playing,
                       color: foregroundColor,
                       loopMode: .playOnce,
                       completion: onAnimationCompleted)
                .frame(width: width)
                .onHover { isHovering = $0 }
                .onTouchDown { isPressed = $0 }
                .simultaneousGesture(TapGesture().onEnded {
                    action?()
                })
        }
    }
}
