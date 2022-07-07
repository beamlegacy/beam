//
//  OmniboxBackground.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

struct OmniboxBeams: View {
    let boxCornerRadius: CGFloat
    let shadowRadius: CGFloat

    @State var angles: [Double] = [0, 0, 0, 0]

    static let colors = [colorsForGradient(), colorsForGradient(), colorsForGradient(), colorsForGradient()]

    static var randomColor: Color {
        Color(hue: Double.random(in: 0...1),
              saturation: Double.random(in: 0.7...1),
              brightness: Double.random(in: 0.7...1.0))
        .opacity(Double.random(in: 0.0...0.9))
    }

    static func colorsForGradient() -> [Color] {
        var _colors = [Color]()
        for _ in 0...40 {
            _colors.append(randomColor)
        }
        _colors.append(_colors[0])
        return _colors
    }

    func part(index: Int, lineWidth: Double) -> some View {
        RoundedRectangle(cornerRadius: boxCornerRadius)
            .stroke(AngularGradient(colors: Self.colors[index], center: UnitPoint(x: 0.5, y: 0.5), angle: .degrees(angles[index])), lineWidth: lineWidth)
            .blendMode(.plusLighter)
            .onAppear {
                let baseAnimation = Animation.linear(duration: 100)
                let repeated = baseAnimation.repeatForever(autoreverses: false)

                withAnimation(repeated) {
                    angles[index] = angles[index] + Double(index + 1) * (index.isMultiple(of: 2) ? 360 : -360)
                }
            }
    }

    func contour(lineWidth: Double) -> some View {
        ZStack {
            part(index: 0, lineWidth: lineWidth)
            part(index: 1, lineWidth: lineWidth)
            part(index: 2, lineWidth: lineWidth)
            part(index: 3, lineWidth: lineWidth)
        }
    }

    var body: some View {
        ZStack {
            contour(lineWidth: 10)
                .blur(radius: 64)
                .opacity(1.0 - 1.0 / shadowRadius)

            contour(lineWidth: 2)
                .opacity(0.3)
        }
    }
}

extension Omnibox {

    struct Background<Content: View>: View {
        var isLow = false
        var isPressingCharacter = false
        var alignment: Alignment = .center
        var content: () -> Content

        private let boxCornerRadius: CGFloat = 10
        private let defaultStrokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.3))
        private let lowStrokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.15))
        private let defaultBackgroundColor = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)
        private let lowBackgroundColor = BeamColor.Generic.background

        private let baseShadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.36), darkColor: .From(color: .black, alpha: 0.7))
        private let pulledShadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.07), darkColor: .From(color: .black, alpha: 0.3))

        private var backgroundColor: Color {
            (isLow ? lowBackgroundColor : defaultBackgroundColor).swiftUI
        }
        private var strokeColor: Color {
            (isLow ? lowStrokeColor : defaultStrokeColor).swiftUI
        }
        private var shadowColor: Color {
            (isLow ? pulledShadowColor.alpha(0) : baseShadowColor).swiftUI
        }
        private var shadowRadius: CGFloat {
            (isLow ? 0 : 32) * (isPressingCharacter ? 1/3 : 1.0)
        }
        private var shadowOffsetY: CGFloat {
            (isLow ? 0 : 14) * (isPressingCharacter ? 1/3 : 1.0)
        }

        private let animationDuration: Double = 0.3

        @State private var useBeams = PreferencesManager.enableOmnibeams

        var body: some View {
            ZStack(alignment: alignment) {
                if useBeams {
                    OmniboxBeams(boxCornerRadius: boxCornerRadius, shadowRadius: shadowRadius)
                }

                RoundedRectangle(cornerRadius: boxCornerRadius)
                    .stroke(strokeColor, lineWidth: isLow ? 2 : 1) // 1pt centered stroke, makes it a 0.5pt outer stroke.
                if !useBeams {
                    VisualEffectView(material: .headerView)
                        .cornerRadius(boxCornerRadius)
                        .shadow(color: shadowColor, radius: shadowRadius, x: 0.0, y: shadowOffsetY)
                } else {
                    VisualEffectView(material: .headerView)
                        .cornerRadius(boxCornerRadius)
                }
                RoundedRectangle(cornerRadius: boxCornerRadius)
                    .fill(backgroundColor.opacity(0.4))
                content()
                    .cornerRadius(boxCornerRadius)
                    .clipped()
            }
        }
    }
}
