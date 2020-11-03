//
//  GlobalTabTitle.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct GlobalTabTitle: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab

    var body: some View {
        Text(tab.originalQuery)
            .font(.custom("SF-Pro-Text-Heavy", size: 16))
            .offset(x: 0, y: 7)
    }
}
