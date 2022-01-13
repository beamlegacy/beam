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

    @StateObject private var viewModel = ViewModel()
    private class ViewModel: ObservableObject {
        @Published var allowTransparentBackground = true
        var backgroundVisibilityDispatchItem: DispatchWorkItem?
    }

    private let webOverlayTransition = AnyTransition.asymmetric(insertion: .opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                                                removal: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.15).delay(0.25)))
    private let notwebOverlayTransition = AnyTransition.asymmetric(insertion: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.15)),
                                                                   removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
    private let overlayOpacity = PreferencesManager.editorToolbarOverlayOpacity
    private var blurOverlay: some View {
        VStack(spacing: 0) {
            if isMainWindow {
                if state.mode == .web {
                    ZStack {
                        BeamColor.AlphaGray.swiftUI.opacity(0.425)
                        BeamColor.Generic.background.swiftUI.opacity(overlayOpacity)
                    }
                    .transition(webOverlayTransition)
                    Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparatorWeb)
                        .transition(webOverlayTransition)
                } else {
                    BeamColor.Generic.background.swiftUI.opacity(overlayOpacity)
                        .transition(notwebOverlayTransition)
                    Separator(horizontal: true, hairline: true, color: BeamColor.ToolBar.backgroundBottomSeparator)
                        .transition(notwebOverlayTransition)
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
            .background(ClickCatchingView(onTap: { _ in }, onDoubleTap: { _ in
                state.associatedWindow?.zoom(nil)
            }))
            .background(
                VisualEffectView(material: .headerView)
                    .overlay(blurOverlay)
                    .opacity(!isMainWindow || !viewModel.allowTransparentBackground || isAboveContent ? 1 : 0)
            )
            .zIndex(10)
            .onChange(of: mode) { [mode] newMode in
                updateBackgroundVisibility(mode: newMode, previousMode: mode)
            }
            .onAppear {
                viewModel.allowTransparentBackground = mode != .web
            }
    }

    private func updateBackgroundVisibility(mode: Mode, previousMode: Mode) {
        guard previousMode != mode else { return }
        viewModel.backgroundVisibilityDispatchItem?.cancel()
        if mode == .web {
            if isAboveContent {
                viewModel.allowTransparentBackground = false
            } else {
                withAnimation(BeamAnimation.easeInOut(duration: 0.05)) {
                    viewModel.allowTransparentBackground = false
                }
            }
        } else if previousMode == .web {
            let workItem = DispatchWorkItem { [weak viewModel] in
                withAnimation(BeamAnimation.easeInOut(duration: 0.1)) {
                    viewModel?.allowTransparentBackground = true
                }
            }
            viewModel.backgroundVisibilityDispatchItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250), execute: workItem)
        }
    }
}

struct Toolbar_Previews: PreviewProvider {
    static var previews: some View {
        Toolbar()
    }
}
