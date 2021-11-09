//
//  AnimatedGradient.swift
//  Beam
//
//  Created by Remi Santos on 08/11/2021.
//

import SwiftUI

struct AnimatedGradient: View {

    var duration: Double = 20 // seconds

    static let startColor = BeamColor.Gradient.beamGradientStart.swiftUI
    static let endColor = BeamColor.Gradient.beamGradientEnd.swiftUI
    private let colors = [
        Self.startColor,
        Self.endColor,
        Self.startColor,
        Self.endColor
    ]
    @State private var startPoint = UnitPoint(x: 0, y: 0)
    @State private var endPoint = UnitPoint(x: 1, y: 1)

    @State private var isAnimating = false
    private var foreverAnimation: Animation {
        Animation.linear(duration: duration)
            .repeatForever(autoreverses: false)
    }

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
                .frame(width: proxy.size.width * 3)
                .offset(x: isAnimating ? -proxy.size.width * 2 : 0, y: 0)
                .animation(foreverAnimation, value: isAnimating)
        }
        .clipped()
        .onAppear {
            isAnimating = true
        }
    }
}

struct GradientButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Default Duration")
                .foregroundColor(Color.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 50)
                .background(AnimatedGradient())
            AnimatedGradient(duration: 2)
                .frame(width: 300, height: 32)
                .overlay(Text("2s duration").foregroundColor(Color.white))
        }
        .padding()
    }
}
