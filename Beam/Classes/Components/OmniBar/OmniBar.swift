//
//  OmniBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import SwiftUI
import BeamCore

struct OmniBar: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    var isAboveContent: Bool = false

    @State private var title = ""
    @State private var modifierFlagsPressed: NSEvent.ModifierFlags?

    private var enableAnimations: Bool {
        !state.windowIsResizing
    }
    private let windowControlsWidth: CGFloat = 92
    private var boxHeight: CGFloat {
        return isEditing ? 40 : 32
    }

    private var isEditing: Bool {
        return state.focusOmniBox
    }

    private func setIsEditing(_ editing: Bool) {
        state.focusOmniBox = editing
        if editing {
            if let url = browserTabsManager.currentTab?.url?.absoluteString, state.mode == .web {
                autocompleteManager.searchQuerySelectedRange = url.wholeRange
                autocompleteManager.searchQuery = url
            }
        } else if state.mode == .web {
            autocompleteManager.resetQuery()
        }
    }

    private var shouldShowAutocompleteResults: Bool {
        isEditing &&
            !autocompleteManager.searchQuery.isEmpty &&
            !autocompleteManager.autocompleteResults.isEmpty &&
            autocompleteManager.searchQuery != browserTabsManager.currentTab?.url?.absoluteString
    }
    private var showDestinationNotePicker: Bool {
        state.mode == .web && browserTabsManager.currentTab != nil
    }
    private var showPivotButton: Bool {
        state.hasBrowserTabs && !state.destinationCardIsFocused
    }
    private var hasRightActions: Bool {
        return showPivotButton || showDestinationNotePicker
    }
    private var barShadowColor: Color {
        isAboveContent ? BeamColor.BottomBar.shadow.swiftUI : BeamColor.BottomBar.shadow.swiftUI.opacity(0.0)
    }

    var body: some View {
        GeometryReader { containerGeometry in
            HStack(alignment: .top, spacing: 2) {
                OmniBarFieldBackground(isEditing: isEditing, enableAnimations: enableAnimations) {
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
                                }), modifierFlagsPressed: $modifierFlagsPressed, enableAnimations: enableAnimations)
                                .frame(maxHeight: .infinity)
                            }
                            .padding(.leading, !isEditing && state.mode == .web ? 8 : 7)
                        }
                        .animation(enableAnimations ? .easeInOut(duration: 0.3) : nil)
                        .padding(.leading, BeamSpacing._50)
                        .padding(.trailing, BeamSpacing._120)
                        .frame(height: boxHeight)
                        .frame(maxWidth: .infinity)
                        if shouldShowAutocompleteResults {
                            AutocompleteList(selectedIndex: $autocompleteManager.autocompleteSelectedIndex, elements: $autocompleteManager.autocompleteResults, modifierFlagsPressed: modifierFlagsPressed)
                        }
                    }
                }
                .gesture(DragGesture(minimumDistance: 0).onEnded { (value) in
                    // onTapGesture is triggered when moving NSWindow quickly.
                    // Using a drag gesture instead to make sure the cursor hasn't moved.
                    guard value.translation.width == 0.0 && value.translation.height == 0.0 else {
                        return
                    }
                    setIsEditing(true)
                })
                .padding(.trailing, isEditing ? 6 : 10)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                if hasRightActions {
                    HStack(alignment: .center) {
                        if showDestinationNotePicker {
                            DestinationNotePicker(tab: browserTabsManager.currentTab!)
                                .frame(height: 32, alignment: .top)
                        }
                        if showPivotButton {
                            OmniBarButton(icon: state.mode == .web ? "nav-pivot_card" : "nav-pivot_web", accessibilityId: state.mode == .web ? "pivot-card" : "pivot-web", action: toggleMode, size: 32)
                                .frame(height: 32, alignment: .top)
                        }
                    }
                    .padding(.trailing, BeamSpacing._100)
                    .frame(height: boxHeight)
                }
            }
            .animation(enableAnimations ? .easeInOut(duration: 0.3) : nil)
            .padding(.top, isEditing ? 6 : 10)
            .padding(.leading, state.isFullScreen ? 0 : windowControlsWidth)
            .frame(height: 52, alignment: .top)
            .background(BeamColor.Generic.background.swiftUI
                            .shadow(color: barShadowColor, radius: 0, x: 0, y: 0.5)
            )
        }
        .frame(height: 52, alignment: .top)
    }

    func resetAutocompleteSelection() {
        autocompleteManager.resetAutocompleteSelection()
    }

    func goToJournal() {
        state.mode = .today
    }

    func refreshWeb() {
        browserTabsManager.reloadCurrentTab()
    }

    func toggleMode() {
        if state.mode == .web {
            guard let tab = browserTabsManager.currentTab else { return }
            state.navigateToNote(tab.note)
            autocompleteManager.resetQuery()
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
        let origin = BrowsingTreeOrigin.searchBar(query: "query")
        focusedState.browserTabsManager.currentTab = BrowserTab(state: focusedState, browsingTreeOrigin: origin, note: BeamNote(title: "Note title"))
        return Group {
            OmniBar().environmentObject(state)
            OmniBar().environmentObject(focusedState)
        }.previewLayout(.fixed(width: 500, height: 60))
    }
}
