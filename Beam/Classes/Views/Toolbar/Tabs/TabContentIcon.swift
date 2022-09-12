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
        var color = BeamColor.combining(lightColor: .LightStoneGray, darkColor: .Corduroy)
        var hoveredColor = BeamColor.combining(lightColor: .Corduroy, darkColor: .Corduroy)
        var pressedColor = BeamColor.Niobium

        private let invertedColor = BeamColor.combining(lightColor: .Corduroy, darkColor: .LightStoneGray)
        private let invertedhoveredColor = BeamColor.combining(lightColor: .Corduroy, darkColor: .Corduroy)
        private let invertedPressedColor = BeamColor.Niobium.inverted(true)

        var invertedColors: Bool = false
        var action: (() -> Void)?

        @State private var isHovering = false
        @State private var isPressed = false

        private var foregroundColor: Color {
            if isPressed {
                return (invertedColors ? invertedPressedColor : pressedColor).swiftUI
            } else if isHovering {
                return (invertedColors ? invertedhoveredColor : hoveredColor).swiftUI
            }
            return (invertedColors ? invertedColor : color).swiftUI
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
}
