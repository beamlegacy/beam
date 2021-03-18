//
//  PointAndShootFrame.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/03/2021.
//

import Foundation
import SwiftUI

struct ShootFrame: View {

    @ObservedObject var tab: BrowserTab
    var body: some View {
        if tab.shootSelectionUIs.count > 0 {
            let selectionUI = tab.shootSelectionUIs[0]  // TODO: Support mutliple shoots
            let rect = selectionUI.rect
            let color = selectionUI.color
            Rectangle()
                    .animation(selectionUI.animated ? Animation.easeOut : nil)
                    .offset(x: rect.minX, y: rect.minY)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.width / 2, y: rect.height / 2)
                    .foregroundColor(color)
        }
    }
}
