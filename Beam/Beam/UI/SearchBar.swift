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
        SearchBar(searchText: $state.searchQuery, selectionIndex: $state.selectionIndex)
    }
}

struct SearchBar: View {
    @EnvironmentObject var state: BeamState
    @Binding var searchText: String
    @Binding var selectionIndex: Int
    
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
//                        print("searchText activated: \(searchText)")
                        state.mode = .web
                        let index = state.selectionIndex
                        if index != 0 {
                            state.webViewStore.webView.load(URLRequest(url: URL(string: searchText)!))
                        } else {
                            let q = state.completedQueries[index].string
                            let query = q .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

                            let t = "http://www.google.com/search?q=\(query)"
                            state.searchQuery = t
                            state.webViewStore.webView.load(URLRequest(url: URL(string: t)!))
                        }
                       },
                       onCursorMovement: { cursorMovement in
                        let range = 0...max(state.completedQueries.count - 1, 0)
                            switch cursorMovement {
                            case .up:
                                selectionIndex = range.clamp(selectionIndex - 1)
                                return true
                            case .down:
                                selectionIndex = range.clamp(selectionIndex + 1)
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

