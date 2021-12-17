//
//  Toolbar.swift
//  Beam
//
//  Created by Remi Santos on 25/11/2021.
//

import SwiftUI

struct Toolbar: View {

    static let height: CGFloat = 52

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @Environment(\.isMainWindow) private var isMainWindow
    @Environment(\.colorScheme) private var colorScheme

    var isAboveContent = false
    @State private var allowTransparentBackground = true

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
        let mode = state.mode
        ToolbarContentView()
            .environmentObject(state.autocompleteManager)
            .zIndex(11)
        .background(
            VisualEffectView(material: .headerView)
                .overlay(blurOverlay)
                .opacity(!allowTransparentBackground || isAboveContent ? 1 : 0)
        )
        .zIndex(10)
        .onChange(of: mode) { [mode] newMode in
            updateBackgroundVisibility(mode: newMode, previousMode: mode)
        }
        .onAppear {
            allowTransparentBackground = mode != .web
        }
    }

    private let backgroundTransitionAnimation = BeamAnimation.easeInOut(duration: 0.1)

    private func updateBackgroundVisibility(mode: Mode, previousMode: Mode) {
        guard previousMode != mode else { return }
        if mode == .web {
            if isAboveContent {
                allowTransparentBackground = false
            } else {
                withAnimation(BeamAnimation.easeInOut(duration: 0.05)) {
                    allowTransparentBackground = false
                }
            }
        } else if previousMode == .web {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                withAnimation(backgroundTransitionAnimation) {
                    allowTransparentBackground = true
                }
            }
        }
    }
}

struct Toolbar_Previews: PreviewProvider {
    static var previews: some View {
        Toolbar()
    }
}
