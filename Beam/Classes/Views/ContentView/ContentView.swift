//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var onboardingManager: OnboardingManager

    @State private var contentIsScrolled = false
    private var showOmnibarBorder: Bool {
        contentIsScrolled && [.note, .today].contains(state.mode)
    }

    var mainAppContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                OmniBar(isAboveContent: showOmnibarBorder)
                    .environmentObject(state.autocompleteManager)
                    .zIndex(10)
                ModeView(containerGeometry: geometry, contentIsScrolled: $contentIsScrolled)
                if shouldDisplayBottomBar {
                    WindowBottomToolBar()
                        .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.2)))
                }
            }.overlay(
                state.useOmniboxV2 ?
                OmniboxV2Container()
                    .environmentObject(state.autocompleteManager)
                : nil,
                alignment: .top
            )
        }
    }

    var body: some View {
        ZStack {
            Group {
                if onboardingManager.needsToDisplayOnboard {
                    OnboardingView(model: onboardingManager)
                        .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
                } else {
                    mainAppContent
                        .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
                }
            }
            .frame(minWidth: 800)
            .background(BeamColor.Generic.background.swiftUI)
            .edgesIgnoringSafeArea(.top)
            .zIndex(0)
            OverlayViewCenter(viewModel: state.overlayViewModel)
                .edgesIgnoringSafeArea(.top)
                .zIndex(1)
        }
    }

    private var shouldDisplayBottomBar: Bool {
        switch state.mode {
        case .web:
            return false
        case .page:
            guard let page = state.currentPage, page.id != WindowPage.shortcutsWindowPage.id else { return false }
            return true
        default:
            return true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
