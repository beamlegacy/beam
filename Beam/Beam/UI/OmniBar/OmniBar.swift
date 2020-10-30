//
//  OmniBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import AppKit

struct OmniBar: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab
    var canSearch: Bool { state.searchQuery.isEmpty && state.currentNote == nil }

    var body: some View {
        HStack {
            Chevrons()

            if state.mode == .note {
                HStack {
                    if let note = state.currentNote {
                        GlobalNoteTitle(note: note)
                    } else {
                        OmniBarSearchBox()
                    }

                    Button(action: startQuery) {
                        Symbol(name: "magnifyingglass")
                    }
                    .disabled(canSearch)
                    .buttonStyle(RoundRectButtonStyle())
                    .padding(.leading, 1)

                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }
                    .buttonStyle(RoundRectButtonStyle())
                }.padding(.leading, 9)

            } else {
                VStack {
                    GlobalTabTitle(tab: state.currentTab)
                        .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 28, alignment: .center)
                    GeometryReader { geometry in
                        Path { path in
                            let f = CGFloat(tab.estimatedProgress)
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: geometry.size.width * f, y: 0))
                            path.addLine(to: CGPoint(x: geometry.size.width * f, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                            path.move(to: CGPoint(x: 0, y: 0))
                        }
                        .fill(tab.isLoading ? Color.accentColor.opacity(0.5): Color.accentColor.opacity(0))
                    }
                    .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 2, alignment: .center)
                    .animation(.easeIn(duration: 0.5))
                }
            }

            Button(action: toggleMode) {
                Symbol(name: state.mode == .web ? "note.text" : "network")
            }.buttonStyle(RoundRectButtonStyle()).disabled(state.tabs.isEmpty)

        }.padding(.top, 10).padding(.bottom, 10).frame(height: 54, alignment: .topLeading)
    }

    func cancelAutocomplete() {
        state.searchQuerySelection = nil
        state.selectionIndex = nil
    }

    func startNewSearch() {
        cancelAutocomplete()
        state.searchQuery = ""
        state.mode = .note
    }

    func startQuery() {
        withAnimation {
            //print("searchText activated: \(searchText)")
            if state.searchQuery.isEmpty {
                state.currentNote = nil
            } else {
                state.startQuery()
            }
        }
    }

    func toggleMode() {
        if state.mode == .web {
            if let note = state.currentTab.note {
                state.currentNote = note
            }
            state.mode = .note
            state.resetQuery()
        } else {
            state.mode = .web
        }
    }
}
