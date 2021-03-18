//
//  PointAndShootFrame.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/03/2021.
//

import Foundation
import SwiftUI

struct PointAndshootFrame: View {
    @ObservedObject var tab: BrowserTab
    var body: some View {
        if let rect = tab.pointAndShootRect {
            Rectangle()
                .animation(nil)
                .offset(x: rect.minX, y: rect.minY)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.width / 2, y: rect.height / 2)
                .foregroundColor(Color(red: 0, green: 0, blue: 0, opacity: 0.1))
        }
    }
}
