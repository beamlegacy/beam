//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI
import BeamCore

struct ModeView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var data: BeamData

    @State private var contentIsScrolled = false

    var showOmnibarBorder: Bool {
        contentIsScrolled && [.note, .today].contains(state.mode)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                OmniBar(isAboveContent: showOmnibarBorder)
                    .environmentObject(state.autocompleteManager)
                    .zIndex(10)
                ZStack {
                    switch state.mode {
                    case .web:
                        VStack(spacing: 0) {
                            BrowserTabBar(tabs: $state.tabs, currentTab: $state.currentTab)
                                .zIndex(9)

                            if let tab = state.currentTab {

                                ZStack {
                                    WebView(webView: tab.webView)
                                            .accessibility(identifier: "webView")

                                    if data.showTabStats, let score = tab.browsingTree.current.score {
                                        TabStats(score: score)
                                    }

                                    PointFrame(pointAndShootUI: tab.pointAndShootMessageHandler!.pointAndShoot.ui)
                                    ShootFrame(pointAndShootUI: tab.pointAndShootMessageHandler!.pointAndShoot.ui)
                                }.clipped()
                            }
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut(duration: 0.3))
                    case .note:
                        ZStack {
                            NoteView(note: state.currentNote!,
                                     showTitle: false,
                                     scrollable: true,
                                     centerText: true) { scrollPoint in
                                contentIsScrolled = scrollPoint.y > NoteView.topOffset
                            }
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            contentIsScrolled = false
                        }
                    case .today:
                        JournalScrollView(axes: [.vertical],
                                          showsIndicators: false,
                                          proxy: geometry) { scrollPoint in
                            contentIsScrolled = scrollPoint.y >
                                JournalScrollView.firstNoteTopOffset(forProxy: geometry) + NoteView.topOffset
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .onAppear {
                            contentIsScrolled = false
                        }
                        .onDisappear {
                            data.reloadJournal()
                        }
                        .accessibility(identifier: "journalView")
                    case .page:
                        if let page = state.currentPage {
                            WindowPageView(page: page)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                if state.mode != .web {
                    WindowBottomToolBar()
                        .transition(.offset(x: 0, y: 30))
                }
            }
            .background(BeamColor.Generic.background.swiftUI)
        }.frame(minWidth: 800)
    }
}

struct ContentView: View {
    var body: some View {
        ModeView()
            .background(BeamColor.Generic.background.swiftUI)
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
