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
    @State private var showDownloadPanel: Bool = false

    private var enableAnimations: Bool {
        !state.windowIsResizing
    }
    private let windowControlsWidth: CGFloat = 92
    private let boxHeightEditing: CGFloat = 40
    private var boxHeight: CGFloat {
        return isEditing ? boxHeightEditing : 32
    }

    private var isEditing: Bool {
        return state.focusOmniBox
    }

    private func setIsEditing(_ editing: Bool) {
        state.focusOmniBox = editing
        if editing {
            if let url = browserTabsManager.currentTab?.url?.absoluteString, state.mode == .web {
                autocompleteManager.searchQuerySelectedRange = url.wholeRange
                autocompleteManager.setQueryWithoutAutocompleting(url)
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
    private var showDownloadsButton: Bool {
        !state.data.downloadManager.downloads.isEmpty
    }
    private var showPressedState: Bool {
        state.autocompleteManager.animateInputingCharacter
    }

    private var defaultAnimation: Animation? {
        enableAnimations ? .easeInOut(duration: 0.3) : nil
    }

    // MARK: Views
    private func fieldView(containerGeometry: GeometryProxy) -> some View {
        OmniBarFieldBackground(isEditing: isEditing,
                               isPressingCharacter: showPressedState,
                               enableAnimations: enableAnimations) {
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
                        }),
                        modifierFlagsPressed: $modifierFlagsPressed,
                        enableAnimations: enableAnimations)
                        .frame(maxHeight: .infinity)
                    }
                    .padding(.leading, !isEditing && state.mode == .web ? 8 : 7)
                }
                .animation(defaultAnimation)
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
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.trailing, isEditing ? 6 : 10)
        .padding(.top, isEditing ? 6 : 10)
        .animation(defaultAnimation)
        .animatableOffsetEffect(offset: CGSize(width: 0, height: showPressedState ? 3 : 0))
    }

    var rightActionsView: some View {
        Group {
            if hasRightActions {
                HStack(alignment: .center) {
                    if showDownloadsButton {
                        OmniBarDownloadButton(downloadManager: state.data.downloadManager, action: {
                            showDownloadPanel.toggle()
                        })
                        .frame(height: 32, alignment: .top)
                        .background(GeometryReader { proxy -> Color in
                            let rect = proxy.frame(in: .global)
                            let center = CGPoint(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height / 2)
                            state.downloadButtonPosition = center
                            return Color.clear
                        })
                    }
                    if showDestinationNotePicker, let currentTab = browserTabsManager.currentTab {
                        DestinationNotePicker(tab: currentTab)
                            .frame(height: 32, alignment: .top)
                    }
                    if showPivotButton {
                        OmniBarButton(icon: state.mode == .web ? "nav-pivot_card" : "nav-pivot_web", accessibilityId: state.mode == .web ? "pivot-card" : "pivot-web", action: toggleMode, size: 32)
                            .frame(height: 32, alignment: .top)
                    }
                }
                .padding(.top, BeamSpacing._100)
                .padding(.trailing, BeamSpacing._100)
                .frame(height: boxHeightEditing)
                .animation(defaultAnimation)
            }
        }
    }

    var body: some View {
        GeometryReader { containerGeometry in
            HStack(alignment: .top, spacing: 2) {
                fieldView(containerGeometry: containerGeometry)
                rightActionsView
            }
            .padding(.leading, state.isFullScreen ? 0 : windowControlsWidth)
            .frame(height: 52, alignment: .top)
            .background(BeamColor.Generic.background.swiftUI
                            .shadow(color: barShadowColor, radius: 0, x: 0, y: 0.5)
            )
        }
        .popup(isPresented: showDownloadPanel, config: .init(alignment: .topTrailing, offset: CGSize(width: -18, height: 45))) {
            DownloaderView(downloader: state.data.downloadManager, isPresented: $showDownloadPanel)
        }
        .frame(height: 52, alignment: .top)
    }

    // MARK: Actions
    func resetAutocompleteSelection() {
        autocompleteManager.resetAutocompleteSelection()
    }

    func goToJournal() {
        state.navigateToJournal(clearNavigation: true)
    }

    func refreshWeb() {
        browserTabsManager.reloadCurrentTab()
    }

    func toggleMode() {
        if state.mode == .web {
            guard let tab = browserTabsManager.currentTab else { return }
            state.navigateToNote(tab.noteController.note)
            autocompleteManager.resetQuery()
        } else {
            state.mode = .web
        }
    }
}

struct OmniBar_Previews: PreviewProvider {
    static let state = BeamState()
    static let focusedState = BeamState()
    static let beamData = BeamData()
    static let autocompleteManager = AutocompleteManager(with: beamData, searchEngine: GoogleSearch())
    static let browserTabManager = BrowserTabsManager(with: beamData)

    static var previews: some View {
        state.focusOmniBox = false
        focusedState.focusOmniBox = true
        focusedState.mode = .web
        let origin = BrowsingTreeOrigin.searchBar(query: "query")
        focusedState.browserTabsManager.currentTab = BrowserTab(state: focusedState, browsingTreeOrigin: origin, note: BeamNote(title: "Note title"))
        return Group {
            OmniBar()
                .environmentObject(state)
                .environmentObject(autocompleteManager)
                .environmentObject(browserTabManager)
            OmniBar()
                .environmentObject(focusedState)
                .environmentObject(autocompleteManager)
                .environmentObject(browserTabManager)
        }.previewLayout(.fixed(width: 500, height: 60))
    }
}
