//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct ModeView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var data: BeamData
    private let windowControlsWidth: CGFloat = 92

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                OmniBar(containerGeometry: geometry)
                    .environmentObject(state.autocompleteManager)
                    .padding(.leading, state.isFullScreen ? 0 : windowControlsWidth)
                    .zIndex(10)
                    .frame(height: 52, alignment: .top)

                ZStack {
                    switch state.mode {
                    case .web:
                        VStack(spacing: 0) {
                            BrowserTabBar(tabs: $state.tabs, currentTab: $state.currentTab)
                                .frame(width: geometry.size.width, height: 28)

                            if let tab = state.currentTab {
                                ZStack {
                                    WebView(webView: tab.webView)
                                            .accessibility(identifier: "webView")

                                    if data.showTabStats, let score = tab.browsingTree.current.score {
                                        TabStats(score: score)
                                    }

                                    PointFrame(pointAndShoot: tab.pointAndShoot)
                                    ShootFrame(pointAndShoot: tab.pointAndShoot)
                                }
                            }
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut(duration: 0.3))

                    case .note:
                        ZStack {
                            NoteView(note: state.currentNote!, showTitle: false, scrollable: true, centerText: true)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .today:
                        GeometryReader { geometry in
                            JournalView(data: state.data, isFetching: state.data.isFetching, journal: state.data.journal, offset: geometry.size.height * 0.4)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                if [.note, .today].contains(state.mode) {
                    WindowBottomToolBar()
                        .transition(.offset(x: 0, y: 30))
                }
            }
            .background(Color(.editorBackgroundColor))
        }.frame(minWidth: 800)
    }
}

struct ContentView: View {
    var body: some View {
        ModeView()
            .background(Color(.editorBackgroundColor))
            .edgesIgnoringSafeArea(.top)
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            ContentView(webViewStore: .constant(WebViewStore()), mode: .web)
//        }
//    }
//}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
