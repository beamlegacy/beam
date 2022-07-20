//
//  ToolbarChevrons.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI
import BeamCore

struct ToolbarChevrons: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
        HStack(spacing: 1) {
            let canGoBackForward = state.canGoBackForward
            let alwaysShow = state.shouldForceShowBackForward
            if canGoBackForward.back || alwaysShow.back {
                ToolbarButton(icon: "nav-back", customIconSize: CGSize(width: 20, height: 24),
                              customContainerSize: CGSize(width: 22, height: 28), action: goBack)
                    .disabled(!canGoBackForward.back)
                    .tooltipOnHover(
                        (state.mode != .web ? Shortcut.AvailableShortcut.goBackEditor : Shortcut.AvailableShortcut.goBack)
                            .description
                    )
                    .accessibilityIdentifier("goBack")
            }
            if canGoBackForward.forward || alwaysShow.forward {
                ToolbarButton(icon: "nav-forward", customIconSize: CGSize(width: 20, height: 24),
                              customContainerSize: CGSize(width: 22, height: 28), action: goForward)
                    .disabled(!canGoBackForward.forward)
                    .tooltipOnHover(
                        (state.mode != .web ? Shortcut.AvailableShortcut.goForwardEditor : Shortcut.AvailableShortcut.goForward)
                            .description
                    )
                    .accessibilityIdentifier("goForward")
            }
        }
    }

    func goBack() {
        let newTab = NSEvent.modifierFlags.contains(.command)
        state.goBack(openingInNewTab: newTab)
    }

    func goForward() {
        let newTab = NSEvent.modifierFlags.contains(.command)
        state.goForward(openingInNewTab: newTab)
    }

}
