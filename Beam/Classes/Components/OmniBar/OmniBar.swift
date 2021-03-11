//
//  OmniBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import Combine
import AppKit

struct OmniBar: View {
    @EnvironmentObject var state: BeamState
    @State var title = ""
    var containerGeometry: GeometryProxy?

    private var boxHeight: CGFloat {
        return isEditing ? 40 : 32
    }

    private var isEditing: Bool {
        return state.focusOmniBox
    }

    private func setIsEditing(_ editing: Bool) {
        state.focusOmniBox = editing
        if editing {
            if let url = state.currentTab?.url?.absoluteString, state.mode == .web {
                state.searchQuery = url
                state.searchQuerySelectedRanges = [0..<url.count]
            }
        } else if state.mode == .web {
            state.resetQuery()
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            OmniBarFieldBackground(isEditing: isEditing) {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        if !isEditing {
                            if state.mode != .today {
                                OmniBarButton(icon: "nav-journal", accessibilityId: "journal", action: goToJournal)
                            }
                            Chevrons()
                            if state.mode == .web {
                                OmniBarButton(icon: "nav-refresh", accessibilityId: "refresh", action: refreshWeb)
                            }
                        }
                        GlobalCenteringContainer(enabled: !isEditing && state.mode != .web, containerGeometry: containerGeometry) {
                            OmniBarSearchField(isEditing: Binding<Bool>(get: {
                                isEditing
                            }, set: {
                                setIsEditing($0)
                            }))
                            .frame(maxHeight: .infinity)
                            .onHover { (hover) in
                                if hover {
                                    NSCursor.iBeam.set()
                                } else {
                                    NSCursor.arrow.set()
                                }
                            }
                        }
                        .padding(.leading, !isEditing && state.mode == .web ? 20 : 7)
                    }
                    .animation(.easeInOut(duration: 0.3))
                    .padding(.horizontal, 5)
                    .frame(height: boxHeight)
                    .frame(maxWidth: .infinity)
                    if isEditing && !state.searchQuery.isEmpty && !state.autocompleteResults.isEmpty {
                        AutocompleteList(selectedIndex: $state.autocompleteSelectedIndex, elements: $state.autocompleteResults)
                    }
                }
            }
            .onTapGesture(perform: {
                setIsEditing(true)
            })
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .center) {
                    if state.mode == .web && state.currentTab != nil {
                        DestinationNotePicker(tab: state.currentTab!)
                            .frame(height: 32, alignment: .top)
                    }
                    if !state.tabs.isEmpty && !state.destinationCardIsFocused {
                        OmniBarButton(icon: state.mode == .web ? "nav-pivot_card" : "nav-pivot_web", accessibilityId: state.mode == .web ? "pivot-card" : "pivot-web", action: toggleMode, size: 32)
                            .frame(height: 32, alignment: .top)
                    }
                }
                .frame(height: boxHeight)
        }
        .animation(.easeInOut(duration: 0.3))
        .padding(.top, isEditing ? 6 : 10)
        .padding(.trailing, 10)
    }

    func resetAutocompleteSelection() {
        state.resetAutocompleteSelection()
    }

    func startNewSearch() {
        state.startNewSearch()
    }

    func goToJournal() {
        state.mode = .today
    }

    func refreshWeb() {
        state.currentTab?.webView.reload()
    }

    func toggleMode() {
        if state.mode == .web {
            guard let tab = state.currentTab else { return }
            state.navigateToNote(tab.note)
            state.resetQuery()
        } else {
            state.mode = .web
        }
    }
}

struct OmniBar_Previews: PreviewProvider {

    static let state = BeamState()
    static let focusedState = BeamState()

    static var previews: some View {
        state.focusOmniBox = false
        focusedState.focusOmniBox = true
        focusedState.mode = .web
        focusedState.currentTab = BrowserTab(state: focusedState, originalQuery: "query", note: BeamNote(title: "Note title"))
        return Group {
            OmniBar().environmentObject(state)
            OmniBar().environmentObject(focusedState)
        }.previewLayout(.fixed(width: 500, height: 60))
    }
}
