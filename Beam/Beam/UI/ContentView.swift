//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct ModeView: View {
    @EnvironmentObject var state: BeamState
    @ViewBuilder
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                OmniBar()
                    .padding(.leading, 73)
                    .padding(.trailing, 20)
                    .frame(height: 52, alignment: .center)

                ZStack {
                    switch state.mode {
                    case .web:
                        VStack(spacing: 0) {
                            BrowserTabBar(tabs: $state.tabs, currentTab: $state.currentTab)
                                .frame(width: geometry.size.width, height: 28)

                            if let tab = state.currentTab {
                                WebView(webView: tab.webView)
                            }
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut(duration: 0.3))
                        .zIndex(1)
                    case .note:
                        ZStack {
                            NoteView(note: state.currentNote!, showTitle: false, scrollable: true)
                        }
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
                    }
                }

            }
            .background(Color("EditorBackgroundColor"))
        }.frame(minWidth: 822)
    }
}

struct ContentView: View {
    var body: some View {
        ModeView()
            .background(Color("EditorBackgroundColor").opacity(0.8))
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
