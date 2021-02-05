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
    @ViewBuilder
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack {
                    if !(state.isEditingOmniBarTitle || [Mode.today, Mode.note].contains(state.mode)) {
                        if let tab = state.currentTab {
                            GlobalTabTitle(tab: tab, isEditing: $state.isEditingOmniBarTitle)
                                .frame(width: geometry.size.width * 0.5, height: 52, alignment: .center)
                        }
                    }

                    OmniBar()
                        .padding(.leading, state.isFullScreen ? 0 : 70)
                        .padding(.trailing, 20)
                        .frame(height: 52, alignment: .center)
                }

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

                                    if data.showTabStats, let score = tab.score {
                                        TabStats(score: score)
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut(duration: 0.3))
                        .zIndex(1)
                    case .note:
                        ZStack {
                            NoteView(note: state.currentNote!, showTitle: false, scrollable: true)
                        }
                        .background(Color(.editorBackgroundColor))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3))
                    case .today:
                        GeometryReader { geometry in
                            JournalView(journal: state.data.journal, offset: geometry.size.height * 0.4)
                        }
                    }

                    if !state.searchQuery.isEmpty && !state.completedQueries.isEmpty {
                        ScrollView {
                            AutoCompleteView(autoComplete: $state.completedQueries, selectionIndex: $state.selectionIndex)
                                .frame(minHeight: 20, maxHeight: 250, alignment: .top)
                                .zIndex(2)
                        }
                        .accessibility(identifier: "autoCompleteView")
                    }
                }
            }
            .background(Color(.editorBackgroundColor))
        }.frame(minWidth: 822)
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
