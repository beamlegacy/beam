//
//  SearchBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import AppKit

struct GlobalTabTitle: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab
    
    var body: some View {
        Text(tab.originalQuery)
            .onTapGesture(count: 1, perform: {
                // We should rename the note
                state.mode = .note
                state.searchQuery = tab.originalQuery
            })
            .font(.system(size: 16, weight: .semibold))
    }
}

struct SearchBar: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
        HStack {
            Button(action: goBack) {
                Text("<")
                    .aspectRatio(contentMode: .fit)
            }.buttonStyle(BorderlessButtonStyle()).disabled(!state.canGoBack).frame(alignment: .center)
            Button(action: goForward) {
                Text(">")
                    .aspectRatio(contentMode: .fit)
            }.buttonStyle(BorderlessButtonStyle()).disabled(!state.canGoForward).frame(alignment: .center)
            
            if state.mode == .note {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).foregroundColor(Color("SearchBarBg")).frame(height: 20)
//                    TextField("Search or create note...", text: $state.searchQuery,
                    BTextField("Search or create note...", text: $state.searchQuery,
                               onCommit:  {
                                withAnimation {
                                    //print("searchText activated: \(searchText)")
                                    let query = state.searchQuery
                                    let queries = state.completedQueries
                                    var searchText = query
                                    if let i = state.selectionIndex {
                                        state.searchEngine.query = queries[i].string
                                        searchText = state.searchEngine.searchUrl
                                        print("Start search query: \(searchText)")
                                        //state.searchQuery = t
                                    }
                                    
                                    if searchText.hasPrefix("http://") || searchText.hasPrefix("https://") {
                                        print("Start website query: \(searchText)")
                                    } else {
                                        state.searchEngine.query = searchText
                                        searchText = state.searchEngine.searchUrl
                                        print("Start search query: \(searchText)")
                                    }
                                    
                                    let tab = BrowserTab(originalQuery: query)
                                    tab.webView.load(URLRequest(url: URL(string: searchText)!))
                                    state.currentTab = tab
                                    state.tabs.append(tab)
                                    state.mode = .web
                                }
                               }
                               ,
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
                               },
                               focusOnCreation: true
                    )
                    .padding([.leading, .trailing], 8)
                    .frame(idealWidth: 600, maxWidth: .infinity)
                }
            } else {
                GlobalTabTitle(tab: state.currentTab)
                    .frame(idealWidth: 600, maxWidth: .infinity)
            }
        }.padding(.top, 10).padding(.bottom, 10)
    }
    
    func goBack() {
        state.currentTab.webView.goBack()
    }
    
    func goForward() {
        state.currentTab.webView.goForward()
    }
}

