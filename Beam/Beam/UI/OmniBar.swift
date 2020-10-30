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

private var _cornerRadius = CGFloat(7)
private var buttonFont = SwiftUI.Font.custom("SF Symbols", size: 16)

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
            .font(.custom("SF-Pro-Text-Heavy", size: 16))
            .offset(x: 0, y: 7)
    }
}

struct GlobalNoteTitle: View {
    @EnvironmentObject var state: BeamState
    var note: Note
    @State var isHover = false
    @State var isEditing = false
    @State var isRenaming = false
    @State var title = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color("OmniboxBackgroundColor").opacity(isHover ? 1 : 0)) .frame(height: 28)
            RoundedRectangle(cornerRadius: _cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: isEditing ? 2.5 : 0).frame(height: 28)
            if !isRenaming {
                Text(note.title)
                    .font(.system(size: 16, weight: .heavy))
                    .frame(idealWidth: 600, maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 9)
            } else {
                BTextField(text: $title,
                           isEditing: $isEditing,
                           placeholderText: "note name",
                           onCommit: {
                            withAnimation {
                                isRenaming = false
                                isEditing = false
                                note.title = title
                            }
                           },
                           focusOnCreation: true,
                           textColor: NSColor(named: "OmniboxTextColor"),
                           placeholderTextColor: NSColor(named: "OmniboxPlaceholderTextColor")

                )
                .padding(.top, 8)
                .padding([.leading, .trailing], 9)
                .frame(idealWidth: 600, maxWidth: .infinity)

            }
        }
        .onTapGesture(count: 1, perform: {
            withAnimation {
                isRenaming = true
                title = note.title
            }
        })
        .onHover { h in
            withAnimation {
                isHover = h
            }
        }
        .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 35, idealHeight: 35, maxHeight: 35, alignment: .leading)
    }
}

struct RoundRectButtonStyle: PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State var isHover = false
    var foregroundColor: Color {
        guard isEnabled else { return Color(.displayP3, white: 1, opacity: 0) }
        return isHover ? Color("ToolbarButtonBackgroundOnColor") : Color("ToolbarButtonBackgroundHoverColor")
    }
    public func makeBody(configuration: BorderedButtonStyle.Configuration) -> some View {
        return ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(foregroundColor).frame(width: 33, height: 28, alignment: .center)
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
    @Environment(\.isEnabled) var isEnabled

    var body: some View {
        Image(name).renderingMode(.template)
            .resizable()
            .scaledToFill() // add if you need
            .frame(width: CGFloat(size / 2), height: CGFloat(size), alignment: .center)
    }
}

struct OmniBarSearchBox: View {
    @EnvironmentObject var state: BeamState
    @State var isEditing: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color("OmniboxBackgroundColor")) .frame(height: 28)
            RoundedRectangle(cornerRadius: _cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: isEditing ? 2.5 : 0).frame(height: 28)

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
    }

    func cancelAutocomplete() {
        state.searchQuerySelection = nil
        state.selectionIndex = nil
    }

    func resetSearchQuery() {
        cancelAutocomplete()
        state.searchQuery = ""
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
}

struct OmniBar: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab

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
                    if let note = state.currentNote {
                        GlobalNoteTitle(note: note)

                    } else {
                        OmniBarSearchBox()
                    }

                    Button(action: startQuery) {
                        Symbol(name: "magnifyingglass")
                    }.disabled(state.searchQuery.isEmpty && state.currentNote == nil ).buttonStyle(RoundRectButtonStyle()).padding(.leading, 1)

                    Button(action: startNewSearch) {
                        Symbol(name: "plus")
                    }.buttonStyle(RoundRectButtonStyle())
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
        state.goBack()
    }

    func goForward() {
        state.goForward()
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
