//
//  LinearProgressView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 26/05/2021.
//

import Foundation
import SwiftUI

struct LinearProgressView: View {

    let progress: Double
    let height: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                Rectangle()
                    .frame(height: height)
                    .cornerRadius(1.5)
                    .foregroundColor(BeamColor.Mercury.swiftUI)
                    .blendModeLightMultiplyDarkScreen()
                Rectangle()
                    .frame(width: proxy.size.width * CGFloat(progress), height: height)
                    .cornerRadius(1.5)
                    .foregroundColor(BeamColor.CharmedGreen.swiftUI)
                    .animation(.easeInOut, value: progress)
            }
        }
        .frame(height: 3)
    }
}
