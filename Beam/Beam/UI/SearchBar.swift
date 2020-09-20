//
//  SearchBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import AppKit

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
            BTextField("Search or create note...", text: $searchText,
                       onCommit:  {
                        print("searchText activated: \(searchText)")
                        state.mode = .web
                        state.webViewStore.webView.load(URLRequest(url: URL(string: searchText)!))
                       },
                       onCursorMovement: { cursorMovement in
                            switch cursorMovement {
                            case .up:
                                print("choose previous")
                                return true
                            case .down:
                                print("choose next")
                                return true
                            default:
                                break
                            }
                            return false
                       }
            )
                .frame(idealWidth: 600, maxWidth: .infinity)
        }
    }
    
    func goBack() {
        state.webViewStore.webView.goBack()
    }
    
    func goForward() {
        state.webViewStore.webView.goForward()
    }
}

