//
//  SearchBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import AppKit

struct SearchBar: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
        HStack {
            Button(action: goBack) {
                Text("<")
                    .aspectRatio(contentMode: .fit)
            }.disabled(!state.canGoBack).frame(alignment: .center)
            Button(action: goForward) {
                Text(">")
                    .aspectRatio(contentMode: .fit)
            }.disabled(!state.canGoForward).frame(alignment: .center)
            BTextField("Search or create note...", text: $state.searchQuery,
                       onCommit:  {
                        //print("searchText activated: \(searchText)")
                        let queries = state.completedQueries
                        let index = state.selectionIndex
                        let searchText = state.searchQuery
                        if index != 0 || searchText.hasPrefix("http://") || searchText.hasPrefix("https://") {
                            state.webView.load(URLRequest(url: URL(string: searchText)!))
                            print("Start website query: \(searchText)")
                        } else {
                            let q = queries[index].string
                            let query = q .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                            
                            let t = "http://www.google.com/search?q=\(query)"
                            print("Start search query: \(t)")
                            state.searchQuery = t
                            state.webView.load(URLRequest(url: URL(string: t)!))
                        }
                        state.mode = .web
                       },
                       onCursorMovement: { cursorMovement in
                        switch cursorMovement {
                        case .up:
                            state.selectPreviousAutoComplete()
                            return true
                        case .down:
                            state.selectNextAutoComplete()
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
        state.webView.goBack()
    }
    
    func goForward() {
        state.webView.goForward()
    }

}

