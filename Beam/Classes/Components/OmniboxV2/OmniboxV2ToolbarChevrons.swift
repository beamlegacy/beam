//
//  OmniboxV2ToolbarChevrons.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct OmniboxV2ToolbarChevrons: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
        HStack(spacing: 1) {
            if state.canGoBack {
                OmniboxV2ToolbarButton(icon: "nav-back", customIconSize: CGSize(width: 20, height: 24), customContainerSize: CGSize(width: 22, height: 28), action: goBack)
                    .accessibilityIdentifier("goBack")
            }
            if state.canGoForward {
                OmniboxV2ToolbarButton(icon: "nav-forward", customIconSize: CGSize(width: 20, height: 24), customContainerSize: CGSize(width: 22, height: 28), action: goForward)
                    .accessibilityIdentifier("goForward")
            }
        }
    }

    func goBack() {
        state.goBack()
    }

    func goForward() {
        state.goForward()
    }

}
