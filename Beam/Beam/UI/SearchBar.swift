//
//  SearchBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI

struct SearchBar: View {
    @EnvironmentObject var state: BeamState
    @State var searchText: String
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
                      onEditingChanged: { b in
                        let ac = autoComplete(query: searchText)
                        print("AutoComplete '\(searchText): \(ac)")
                      },
                      onCommit:  {
                        state.mode = .web
                        state.webViewStore.webView.load(URLRequest(url: URL(string: searchText)!))
                      }).frame(idealWidth: 600, maxWidth: .infinity).font(.title)
        }
    }
    
    func goBack() {
        state.webViewStore.webView.goBack()
    }
    
    func goForward() {
        state.webViewStore.webView.goForward()
    }
}

