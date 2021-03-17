//
//  PointAndShootFrame.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/03/2021.
//

import Foundation
import SwiftUI

struct PointAndshootFrame: View {
    var rect: NSRect
    var body: some View {
            Rectangle()
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .foregroundColor(Color.red)
    }
}
