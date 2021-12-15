//
//  OmniboxV2Toolbar.swift
//  Beam
//
//  Created by Remi Santos on 25/11/2021.
//

import SwiftUI

struct OmniboxV2Toolbar: View {

    static let height: CGFloat = 52

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @Environment(\.isMainWindow) private var isMainWindow
    @Environment(\.colorScheme) private var colorScheme

    var isAboveContent = false

    private let webOverlayTransition = AnyTransition.asymmetric(insertion: .opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                                                removal: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.15)))
    private let notwebOverlayTransition = AnyTransition.asymmetric(insertion: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.15)),
                                                                   removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
    private let overlayOpacity = PreferencesManager.editorToolbarOverlayOpacity
    private var blurOverlay: some View {
        VStack(spacing: 0) {
            if isMainWindow {
                if state.mode == .web {
                    ZStack {
                        BeamColor.Generic.background.swiftUI.opacity(overlayOpacity)
                        BeamColor.Mercury.swiftUI.opacity(overlayOpacity)
                    }
                    .transition(webOverlayTransition)
                    Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparatorWeb)
                        .transition(webOverlayTransition)
                } else {
                    BeamColor.Generic.background.swiftUI.opacity(overlayOpacity)
                        .transition(notwebOverlayTransition)
                    Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparator)
                        .transition(notwebOverlayTransition)
                        .opacity(isAboveContent ? 1 : 0)
                }
            } else {
                BeamColor.ToolBar.backgroundInactiveWindow.swiftUI
                Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparatorInactiveWindow)
            }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            OmniBar(isAboveContent: isAboveContent)
                .environmentObject(state.autocompleteManager)
                .zIndex(11)
            if state.mode == .web && !state.useOmniboxV2 {
                BrowserTabBar(tabs: $browserTabsManager.tabs, currentTab: $browserTabsManager.currentTab)
                    .opacity(isMainWindow ? 1 : (colorScheme == .dark ? 0.6 : 0.8))
            }
        }
        .background(
            VisualEffectView(material: .headerView)
                .overlay(blurOverlay)
                .opacity(state.mode == .web || isAboveContent ? 1 : 0)
                .animation(BeamAnimation.easeInOut(duration: 0.05), value: isAboveContent)
        )
        .zIndex(10)
    }
}

struct OmniboxV2Toolbar_Previews: PreviewProvider {
    static var previews: some View {
        OmniboxV2Toolbar()
    }
}
