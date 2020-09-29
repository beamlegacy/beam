//
//  SearchBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import AppKit

fileprivate var _cornerRadius = CGFloat(6)
fileprivate var buttonFont = SwiftUI.Font.custom("SF Symbols", size: 16)

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
            .font(SwiftUI.Font.custom("SF Text", size: 16).weight(.heavy))
    }
}

struct RoundRectButtonStyle : PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State var isHover = false
    public func makeBody(configuration: BorderedButtonStyle.Configuration) -> some View {
        return ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color(isHover ? "ButtonBackgroundOnColor" : "ButtonBackgroundHoverColor")).frame(width: 33, height: 28, alignment: .center)
            configuration.label.foregroundColor(Color(isEnabled ? "ButtonIconColor" : "ButtonIconDisabledColor"))
        }
        .onTapGesture(count: 1) {
            configuration.trigger()
        }
        .onHover { h in
            isHover = h && isEnabled
        }

    }
}

struct Symbol: View {
    var name: String
    var size: Float = 16
    
    var body: some View {
        Image(name).font(.system(size: CGFloat(size))).frame(height: CGFloat(size), alignment: .center)
    }
}

struct SearchBar: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
        HStack {
            Button(action: goBack) {
                Symbol(name: "chevron.left").offset(x: 0, y: -0.5)
            }.buttonStyle(BorderlessButtonStyle()).disabled(!state.canGoBack).padding(.leading, 18)
            Button(action: goForward) {
                Symbol(name: "chevron.right").offset(x: 0, y: -0.5)
            }.buttonStyle(BorderlessButtonStyle()).disabled(!state.canGoForward).padding(.leading, 9)
            
            if state.mode == .note {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color("ButtonBackgroundOnColor")) .frame(height: 28)
                        //                    TextField("Search or create note...", text: $state.searchQuery,
                        
                        HStack {
                            BTextField("Search or create note...", text: $state.searchQuery,
                                       onCommit:  {
                                        startQuery()
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
                                       },
                                       focusOnCreation: true
                            )
                            .padding([.leading, .trailing], 9)
                            .frame(idealWidth: 600, maxWidth: .infinity)
                            
                            Button(action: resetSearchQuery) {
                                Symbol(name: "xmark.circle.fill", size: 12)
                            }.buttonStyle(BorderlessButtonStyle()).disabled(state.searchQuery.isEmpty).padding([.leading, .trailing], 9)
                            
                        }
                    }
                    
                    Button(action: startQuery) {
                        Symbol(name: "magnifyingglass")
                    }.disabled(state.searchQuery.isEmpty).buttonStyle(RoundRectButtonStyle()).padding(.leading, 1)

                    Button(action: startQuery) {
                        Symbol(name: "plus")
                    }.buttonStyle(BorderlessButtonStyle())

                }.padding(.leading, 9)

            } else {
                GlobalTabTitle(tab: state.currentTab)
                    .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 28, alignment: .center)
            }

            Button(action: toggleMode) {
                Symbol(name: state.mode == .web ? "note.text" : "network")
            }.buttonStyle(RoundRectButtonStyle()).disabled(state.tabs.isEmpty)

        }.padding(.top, 10).padding(.bottom, 10)
    }
    
    func goBack() {
        state.currentTab.webView.goBack()
    }
    
    func goForward() {
        state.currentTab.webView.goForward()
    }

    func resetSearchQuery() {
        state.searchQuery = ""
    }
    
    func startQuery() {
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
            state.currentNote = BeamNote(title: query, searchQueries: [query])
            state.mode = .web
        }

    }
    
    func toggleMode() {
        if state.mode == .web {
            state.mode = .note
        } else {
            state.mode = .web
        }
    }
}

