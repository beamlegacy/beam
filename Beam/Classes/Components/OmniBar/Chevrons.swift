//
//  File.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct Chevrons: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
        HStack(spacing: 4) {
            if state.canGoBack {
                OmniBarButton(icon: "nav-back", accessibilityId: "goBack", action: goBack)
            }
            if state.canGoForward {
                OmniBarButton(icon: "nav-forward", accessibilityId: "goForward", action: goForward)
            }
        }
        .animation(.easeInOut)
    }

    func goBack() {
        state.goBack()
    }

    func goForward() {
        state.goForward()
    }

}
