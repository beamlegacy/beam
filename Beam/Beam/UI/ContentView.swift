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
            SearchBar()
                .padding(.leading, 73)
                .padding(.trailing, 20)
                .padding(.top, 2)
            ZStack {
                ScrollView([.vertical]) {
                    NoteView()
                }
                ScrollView([.vertical]) {
                    AutoCompleteView(autoComplete: $state.completedQueries, selectionIndex: $state.selectionIndex)
                        .frame(idealWidth: 800, maxWidth: .infinity, idealHeight: 600, maxHeight: .infinity, alignment: .center)
                    
                }.edgesIgnoringSafeArea(.top)
                
                if state.mode == .web {
                        VStack {
                            BrowserTabBar(tabs: $state.tabs, currentTab: $state.currentTab)
                            WebView(webView: state.currentTab.webView)
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut(duration: 0.3))
                }

            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        ModeView().background(Color("EditorBackgroundColor"))
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
