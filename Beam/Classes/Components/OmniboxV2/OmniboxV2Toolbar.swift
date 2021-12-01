//
//  OmniboxV2Toolbar.swift
//  Beam
//
//  Created by Remi Santos on 25/11/2021.
//

import SwiftUI

struct OmniboxV2Toolbar: View {

    static let height: CGFloat = 52
    static let heightWithTabs: CGFloat = 80

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @Environment(\.isMainWindow) private var isMainWindow
    @Environment(\.colorScheme) private var colorScheme

    var isAboveContent = false

    private let overlayOpacity = PreferencesManager.editorToolbarOverlayOpacity
    private var blurOverlay: some View {
        VStack(spacing: 0) {
            if isMainWindow {
                if state.mode == .web {
                    ZStack {
                        BeamColor.Generic.background.swiftUI.opacity(overlayOpacity)
                        BeamColor.Mercury.swiftUI.opacity(overlayOpacity)
                    }
                    Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparatorWeb)
                } else {
                    BeamColor.Generic.background.swiftUI.opacity(overlayOpacity)
                    if isAboveContent {
                        Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparator)
                    }
                }
            } else {
                BeamColor.ToolBar.backgroundInactiveWindow.swiftUI
                if isAboveContent {
                    Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparatorInactiveWindow)
                }
            }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            OmniBar(isAboveContent: isAboveContent)
                .environmentObject(state.autocompleteManager)
                .zIndex(11)
            if state.mode == .web {
                BrowserTabBar(tabs: $browserTabsManager.tabs, currentTab: $browserTabsManager.currentTab)
                    .opacity(isMainWindow ? 1 : (colorScheme == .dark ? 0.6 : 0.8))
            }
        }
        .background(
            VisualEffectView(material: .headerView)
                .overlay(blurOverlay)
        )
        .zIndex(10)
    }
}

struct OmniboxV2Toolbar_Previews: PreviewProvider {
    static var previews: some View {
        OmniboxV2Toolbar()
    }
}
