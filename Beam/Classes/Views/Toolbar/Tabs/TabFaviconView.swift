//
//  TabFaviconView.swift
//  Beam
//
//  Created by Remi Santos on 09/12/2021.
//

import SwiftUI
import Combine

struct TabFaviconView: View {
    @Environment(\.isMainWindow) private var isMainWindow

    var favIcon: NSImage?
    var isLoading: Bool
    var estimatedLoadingProgress: CGFloat
    var disableAnimations = false

    @State private var loadingIndicatorAnimatedFlag = false
    private var loadingForeverAnimation: Animation {
        Animation.linear(duration: 1.0)
            .repeatForever(autoreverses: false)
    }
    private var loadingIndicator: some View {
        Circle()
            .trim(from: 0.0, to: estimatedLoadingProgress)
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 16)
            .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            .rotationEffect(Angle(degrees: self.loadingIndicatorAnimatedFlag ? 360.0 : 0.0))
            .animation(loadingForeverAnimation, value: self.loadingIndicatorAnimatedFlag)
            .animation(BeamAnimation.easeInOut(duration: 0.15), value: estimatedLoadingProgress)
    }

    var body: some View {
        ZStack {
            if isLoading {
                loadingIndicator
                    .transition(.scale(scale: 0.3).combined(with: .opacity.animation(BeamAnimation.easeInOut(duration: 0.1).delay(0.1))))
                    .onAppear {
                        self.loadingIndicatorAnimatedFlag = true
                    }
                    .onDisappear {
                        self.loadingIndicatorAnimatedFlag = false
                    }
            }
            if let icon = favIcon {
                let iconSize: CGFloat = isLoading ? 10 : 16
                Image(nsImage: icon).resizable().scaledToFit()
                    .cornerRadius(isLoading ? iconSize / 2 : 0)
                    .frame(width: iconSize, height: iconSize)
                    .blendMode(.normal)
                    .if(!isMainWindow) {
                        $0.grayscale(0.99)
                    }
            } else {
                let iconSize: CGFloat = isLoading ? 12 : 16
                Icon(name: "field-web", width: iconSize, color: BeamColor.LightStoneGray.swiftUI)
            }
        }
        .animation(disableAnimations ? nil : BeamAnimation.spring(stiffness: 380, damping: 20), value: isLoading)
    }
}
