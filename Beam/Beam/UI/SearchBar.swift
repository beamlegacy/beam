//
//  SearchBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI

struct MainBar: View {
    @EnvironmentObject var state: BeamState
    var body: some View {
        SearchBar(searchText: $state.searchQuery)
    }
}

struct SearchBar: View {
    @EnvironmentObject var state: BeamState
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Button(action: goBack) {
                Text("<")
                    .aspectRatio(contentMode: .fit)
            }.disabled(!state.webViewStore.webView.canGoBack).frame(alignment: .center)
            Button(action: goForward) {
                Text(">")
                    .aspectRatio(contentMode: .fit)
            }.disabled(!state.webViewStore.webView.canGoForward).frame(alignment: .center)
            TextField("Search or create note...", text: $searchText,
                      onCommit:  {
                        print("searchText activated: \(searchText)")
                        state.mode = .web
                        state.webViewStore.webView.load(URLRequest(url: URL(string: searchText)!))
                      }).textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(idealWidth: 600, maxWidth: .infinity)
                .font(.title)
        }
    }
    
    func goBack() {
        state.webViewStore.webView.goBack()
    }
    
    func goForward() {
        state.webViewStore.webView.goForward()
    }
}

