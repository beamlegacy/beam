//
//  ToolbarChevrons.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct ToolbarChevrons: View {
    @EnvironmentObject var state: BeamState

    private var alwaysShowBack: Bool {
        state.mode == .web && state.browserTabsManager.tabs.first { $0.canGoBack } != nil
    }
    var body: some View {
        HStack(spacing: 1) {
            let alwaysShowBack = alwaysShowBack
            if state.canGoBack || alwaysShowBack {
                ToolbarButton(icon: "nav-back", customIconSize: CGSize(width: 20, height: 24), customContainerSize: CGSize(width: 22, height: 28), action: goBack)
                    .disabled(!state.canGoBack)
                    .accessibilityIdentifier("goBack")
            }
            if state.canGoForward {
                ToolbarButton(icon: "nav-forward", customIconSize: CGSize(width: 20, height: 24), customContainerSize: CGSize(width: 22, height: 28), action: goForward)
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
