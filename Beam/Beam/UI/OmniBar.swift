//
//  OmniBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import AppKit
import VisualEffects

fileprivate var _cornerRadius = CGFloat(7)
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
            .offset(x: 0, y: 7)
    }
}

struct RoundRectButtonStyle : PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State var isHover = false
    public func makeBody(configuration: BorderedButtonStyle.Configuration) -> some View {
        return ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color(isHover ? "ToolbarButtonBackgroundOnColor" : "ToolbarButtonBackgroundHoverColor")).frame(width: 33, height: 28, alignment: .center)
            configuration.label.foregroundColor(Color(isEnabled ? "ToolbarButtonIconColor" : "ToolbarButtonIconDisabledColor"))
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

struct OmniBar: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab
    @State var isEditing: Bool = false

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
                        RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color("OmniboxBackgroundColor")) .frame(height: 28)
                        RoundedRectangle(cornerRadius: _cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: isEditing ? 2.5 : 0).frame(height: 28)
                        //                    TextField("Search or create note...", text: $state.searchQuery,

                        HStack {
                            BTextField(text: $state.searchQuery,
                                       isEditing: $isEditing,
                                       placeholderText: "Search or create note... \(Note.countWithPredicate(CoreDataManager.shared.mainContext)) notes",
                                       selectedRanges: state.searchQuerySelection,
                                       onTextChanged: { _ in
                                        cancelAutocomplete()
                                       },
                                       onCommit: {
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
                                       focusOnCreation: true,
                                       textColor: NSColor(named: "OmniboxTextColor"),
                                       placeholderTextColor: NSColor(named: "OmniboxPlaceholderTextColor")

                            )
                            .padding(.top, 8)
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

                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }.buttonStyle(BorderlessButtonStyle())

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

    func goBack() {
        state.currentTab.webView.goBack()
    }

    func goForward() {
        state.currentTab.webView.goForward()
    }

    func cancelAutocomplete() {
        state.searchQuerySelection = nil
        state.selectionIndex = nil
    }

    func resetSearchQuery() {
        cancelAutocomplete()
        state.searchQuery = ""
    }

    func startNewSearch() {
        cancelAutocomplete()
        state.searchQuery = ""
        state.mode = .note
    }

    func startQuery() {
        if state.searchQuery.isEmpty {
            return
        }
        withAnimation {
            //print("searchText activated: \(searchText)")
            state.startQuery()
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
