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
        VStack {
            OmniBar(tab: state.currentTab)
                .padding(.leading, 73)
                .padding(.trailing, 20)
                .frame(height: 52, alignment: .center)

            ZStack {
                switch state.mode {
                case .web:
                    VStack {
                        BrowserTabBar(tabs: $state.tabs, currentTab: $state.currentTab)
                        WebView(webView: state.currentTab.webView)
                    }
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut(duration: 0.3))
                    .zIndex(1)
                case .note:
                    ScrollView([.vertical]) {
                        ZStack {
                            NoteView(note: state.currentNote!, showTitle: false)
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3))
                case .today:
                    GeometryReader { geometry in
                        JournalView(journal: state.data.journal, offset: geometry.size.height * 0.4)
                    }
                }

                if !state.searchQuery.isEmpty && !state.completedQueries.isEmpty {
                    AutoCompleteView(autoComplete: $state.completedQueries, selectionIndex: $state.selectionIndex).frame(alignment: .top)
                        .zIndex(2)
                }
            }

        }
        .background(Color("EditorBackgroundColor"))
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
