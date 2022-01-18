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
    @State private var startPoint = UnitPoint.bottomLeading
    @State private var endPoint = UnitPoint.topTrailing

    @State private var isAnimating = false
    private var foreverAnimation: Animation {
        Animation.linear(duration: duration)
            .repeatForever(autoreverses: false)
    }

    private func gradient(with proxy: GeometryProxy) -> some View {
        LinearGradient(gradient: .init(colors: colors), startPoint: startPoint, endPoint: endPoint)
            .frame(width: proxy.size.width * 3)
            .offset(x: isAnimating ? -proxy.size.width * 2 : 0, y: 0)
            .animation(foreverAnimation, value: isAnimating)
    }

    var body: some View {
        GeometryReader { proxy in
            if #available(macOS 12, *) {
               gradient(with: proxy)
            } else {
                // Big Sur needs to force draw the entire gradient with .drawingGroup()
                // otherwise it will only render the clipped portion
                gradient(with: proxy)
                    .drawingGroup()
            }
        }
        .clipped()
        .onAppear {
            DispatchQueue.main.async {
                isAnimating = true
            }
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
