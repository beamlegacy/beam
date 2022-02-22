//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    @State private var contentIsScrolled = false
    private var isToolbarAboveContent: Bool {
        contentIsScrolled && [.note, .today].contains(state.mode)
    }

    var mainAppContent: some View {
        GeometryReader { geometry in
            ModeView(containerGeometry: geometry, contentIsScrolled: $contentIsScrolled)
                .frame(maxWidth: .infinity)
                .overlay(Toolbar(isAboveContent: isToolbarAboveContent), alignment: .top)
                .overlay(shouldDisplayBottomBar ?
                         WindowBottomToolBar()
                            .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.2))) : nil, alignment: .bottom)
                .overlay(
                    OmniboxContainer().environmentObject(state.autocompleteManager),
                    alignment: .top
                )
        }
    }

    var body: some View {
        ZStack {
            mainAppContent
                .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
                .frame(minWidth: 800)
                .background(BeamColor.Generic.background.swiftUI)
                .edgesIgnoringSafeArea(.top)
                .zIndex(0)
            OverlayViewCenter(viewModel: state.overlayViewModel)
                .edgesIgnoringSafeArea(.top)
                .zIndex(1)
        }
        .environment(\.isMainWindow, windowInfo.windowIsMain)
        .environment(\.windowFrame, windowInfo.windowFrame)
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

// MARK: - Main Window environment value
private struct IsMainWindowEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var isMainWindow: Bool {
        get { self[IsMainWindowEnvironmentKey.self] }
        set { self[IsMainWindowEnvironmentKey.self] = newValue }
    }
}

// MARK: - Window Frame environment value
private struct WindowFrameEnvironmentKey: EnvironmentKey {
    static let defaultValue = CGRect.zero
}
extension EnvironmentValues {
    var windowFrame: CGRect {
        get { self[WindowFrameEnvironmentKey.self] }
        set { self[WindowFrameEnvironmentKey.self] = newValue }
    }
}
