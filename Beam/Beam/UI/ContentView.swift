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
        switch state.mode {
        case .web:
                VStack {
                    BrowserTabBar(tabs: $state.tabs, currentTab: $state.currentTab)
                    WebView(webView: state.currentTab.webView)
                }
        case .note:
            ScrollView([.vertical]) {
                AutoCompleteView(autoComplete: $state.completedQueries, selectionIndex: $state.selectionIndex)
                    .frame(minWidth: 640, idealWidth: 800, maxWidth: .infinity, minHeight: 480, idealHeight: 600, maxHeight: .infinity, alignment: .center)
                
            }
            
        case .history:
            ScrollView([.vertical]) {
                Text("Bleh\nSome History\nFoo\nBar").frame(minWidth: 640, idealWidth: 800, maxWidth: .infinity, minHeight: 480, idealHeight: 600, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        ModeView().background(Color(.white))
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
