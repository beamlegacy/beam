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
                        print("searchText activated: \(searchText)")
                        state.mode = .web
                        state.webViewStore.webView.load(URLRequest(url: URL(string: searchText)!))
                       },
                       onCursorMovement: { cursorMovement in
                        let range = 0...max(state.completedQueries.count - 1, 0)
                            switch cursorMovement {
                            case .up:
                                selectionIndex = range.clamp(selectionIndex - 1)
                                print("choose prev \(selectionIndex) [\(state.completedQueries.count)]")
                                return true
                            case .down:
                                selectionIndex = range.clamp(selectionIndex + 1)
                                print("choose next \(selectionIndex) [\(state.completedQueries.count)]")
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

