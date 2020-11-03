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
    var canSearch: Bool {
        return !state.searchQuery.isEmpty || !isEditing
    }
    @State var isEditing: Bool = false

    var body: some View {
        HStack {
            Chevrons()

            switch state.mode {
            case .today:
                HStack {
                    OmniBarSearchBox(isEditing: $isEditing)

                    Button(action: isEditing ? startQuery : startNewSearch) {
                        Symbol(name: "magnifyingglass")
                    }
                    .disabled(!canSearch)
                    .buttonStyle(RoundRectButtonStyle())
                    .padding(.leading, 1)

                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }
                    .buttonStyle(RoundRectButtonStyle())
                }.padding(.leading, 9)
            case .note:
                HStack {
                    GlobalNoteTitle(note: state.currentNote!)

                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }
                    .buttonStyle(RoundRectButtonStyle())
                }.padding(.leading, 9)

            case .web:
                HStack {
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

                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }
                    .buttonStyle(RoundRectButtonStyle())
                }
            }

            Button(action: toggleMode) {
                Symbol(name: state.mode == .web ? "note.text" : "network")
            }.buttonStyle(RoundRectButtonStyle()).disabled(state.tabs.isEmpty)

        }.padding(.top, 10).padding(.bottom, 10).frame(height: 54, alignment: .topLeading)
    }

    func resetAutoCompleteSelection() {
        state.resetAutocompleteSelection()
    }

    func startNewSearch() {
        state.cancelAutocomplete()
        state.mode = .today
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
            if state.currentNote != nil {
                state.mode = .note
            } else {
                state.mode = .today
            }
            state.resetQuery()
        } else {
            state.mode = .web
        }
    }
}
