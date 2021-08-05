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

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                Rectangle()
                    .frame(height: 3)
                    .cornerRadius(1.5)
                    .foregroundColor(Color("Mercury"))
                    .blendMode(.multiply)
                Rectangle()
                    .frame(width: proxy.size.width * CGFloat(progress), height: 3)
                    .cornerRadius(1.5)
                    .foregroundColor(Color("CharmedGreen"))
                    .animation(.easeInOut, value: progress)
            }
        }
        .frame(height: 3)
    }
}
