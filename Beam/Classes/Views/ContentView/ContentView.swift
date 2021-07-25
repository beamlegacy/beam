//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: BeamState

    @State private var contentIsScrolled = false
    private var showOmnibarBorder: Bool {
        contentIsScrolled && [.note, .today].contains(state.mode)
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    OmniBar(isAboveContent: showOmnibarBorder)
                        .environmentObject(state.autocompleteManager)
                        .zIndex(10)
                    ModeView(containerGeometry: geometry, contentIsScrolled: $contentIsScrolled)
                    if state.mode != .web {
                        WindowBottomToolBar()
                            .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.2)))
                    }
                }
                .background(BeamColor.Generic.background.swiftUI)
            }
            .frame(minWidth: 800)
                .background(BeamColor.Generic.background.swiftUI)
                .edgesIgnoringSafeArea(.top)
                .zIndex(0)
            OverlayViewCenter(viewModel: state.overlayViewModel)
                .zIndex(1)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
