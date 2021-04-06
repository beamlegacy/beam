//
//  PointAndShootFrame.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/03/2021.
//

import Foundation
import SwiftUI

struct ShootFrame: View {

    @ObservedObject var pointAndShootUI: PointAndShootUI
    var body: some View {
        ZStack {
            let padding: CGFloat = 6
            ForEach(0..<pointAndShootUI.shootSelections.count, id: \.self) { index in
                let selectionUI = pointAndShootUI.shootSelections[index]
                let rect = selectionUI.rect
                RoundedRectangle(cornerRadius: padding, style: .continuous)
                        .stroke(selectionUI.color, lineWidth: 2)
                        .padding(-padding)
                        .animation(selectionUI.animated ? Animation.easeOut : nil)
                        .offset(x: rect.minX, y: rect.minY)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.width / 2, y: rect.height / 2)
            }
        }
    }
}
