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
    @State private var dragStartWindowPosition: CGPoint?

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
            if state.mode == .web, let url = browserTabsManager.currentTab?.url?.absoluteString {
                autocompleteManager.searchQuerySelectedRange = url.wholeRange
                autocompleteManager.setQueryWithoutAutocompleting(url)
            }
        } else if state.mode != .web || browserTabsManager.currentTab?.url != nil {
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
        isAboveContent ? BeamColor.ToolBar.shadowTop.swiftUI : BeamColor.ToolBar.shadowTop.swiftUI.opacity(0.0)
    }
    private var showDownloadsButton: Bool {
        let showButton = !state.data.downloadManager.downloads.isEmpty
        if !showButton {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                state.downloaderWindow?.close()
            }
        }
        return showButton
    }
    private var showPressedState: Bool {
        state.autocompleteManager.animateInputingCharacter
    }

    private var defaultAnimation: Animation? {
        enableAnimations ? .easeInOut(duration: 0.3) : nil
    }

    // MARK: Views
    private func fieldView(containerGeometry: GeometryProxy) -> some View {
        OmniBarFieldBackground(isEditing: isEditing, isPressingCharacter: showPressedState, enableAnimations: enableAnimations) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        leftFieldActions
                    }
                    .animation(enableAnimations ? .easeInOut(duration: isEditing ? 0.1 : 0.3) : nil, value: isEditing)
                    .animation(nil)
                    GlobalCenteringContainer(enabled: !isEditing && state.mode != .web, containerGeometry: containerGeometry) {
                            OmniBarSearchField(isEditing: Binding<Bool>(get: {
                                isEditing
                            }, set: {
                                setIsEditing($0)
                            }),
                            modifierFlagsPressed: $modifierFlagsPressed,
                            enableAnimations: enableAnimations)
                            .frame(maxHeight: .infinity)
                            .offset(x: 0, y: autocompleteManager.animatedQuery != nil ? -12 : 0)
                            .opacity(autocompleteManager.animatedQuery != nil ? 0 : 1)
                            .overlay(cmdReturnAnimatedOverlay)
                    }
                    .padding(.leading, !isEditing && state.mode == .web ? 8 : 7)
                }
                .padding(.leading, BeamSpacing._50)
                .padding(.trailing, BeamSpacing._120)
                .frame(height: boxHeight)
                .frame(maxWidth: .infinity)
                if shouldShowAutocompleteResults {
                    AutocompleteList(selectedIndex: $autocompleteManager.autocompleteSelectedIndex, elements: $autocompleteManager.autocompleteResults, modifierFlagsPressed: modifierFlagsPressed)
                }
            }
        }
        .gesture(DragGesture(minimumDistance: 0)
                    // onTapGesture is triggered when moving NSWindow quickly.
                    // Using a drag gesture instead to make sure the cursor/window hasn't moved.
                    .onChanged { _ in
                        guard dragStartWindowPosition == nil else { return }
                        dragStartWindowPosition = state.windowFrame.origin
                    }
                    .onEnded { value in
                        let windowHasMoved = hasWindowMovedSinceDragStart()
                        dragStartWindowPosition = nil
                        guard value.translation == .zero || !windowHasMoved else { return }
                        setIsEditing(true)
        })
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.trailing, isEditing ? 6 : 10)
        .padding(.top, isEditing ? 6 : 10)
        .animation(defaultAnimation)
        .animatableOffsetEffect(offset: CGSize(width: 0, height: showPressedState ? 3 : 0))
    }

    var leftFieldActions: some View {
        Group {
            if !isEditing {
                if state.mode != .today {
                    OmniBarButton(icon: "nav-journal", accessibilityId: "journal", action: goToJournal)
                        .animation(nil)
                }
                Chevrons()
                    .animation(nil)
                if state.mode == .web, let currentTab = browserTabsManager.currentTab {
                    OmniBarReloadButton(currentTab: currentTab, action: toggleReloadWeb)
                        .animation(nil)
                }
            }
        }
    }

    var cmdReturnAnimatedOverlay: some View {
        Group {
            if let animatedQuery = autocompleteManager.animatedQuery {
                HStack(spacing: BeamSpacing._50) {
                    Icon(name: "field-search", size: 16, color: BeamColor.Bluetiful.swiftUI)
                    Text(animatedQuery)
                        .font(BeamFont.medium(size: 13).swiftUI)
                        .lineLimit(1)
                        .foregroundColor(BeamColor.Bluetiful.swiftUI)
                }
                .transition(AnyTransition.asymmetric(
                    insertion: AnyTransition.move(edge: .bottom).combined(with: .opacity),
                    removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
                ))
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    func rightActionsView(containerGeometry: GeometryProxy) -> some View {
        Group {
            if hasRightActions {
                HStack(alignment: .center) {
                    if showDownloadsButton {
                        OmniBarDownloadButton(downloadManager: state.data.downloadManager, action: {
                            if let downloaderWindow = state.downloaderWindow {
                                downloaderWindow.close()
                            } else if let window = CustomPopoverPresenter.shared.presentPopoverChildWindow() {
                                let downloaderView = DownloaderView(downloader: state.data.downloadManager) { [weak window] in
                                    window?.close()
                                }
                                let omnibarFrame = containerGeometry.safeTopLeftGlobalFrame(in: window.parent)
                                var origin = CGPoint(x: omnibarFrame.origin.x + omnibarFrame.width - DownloaderView.width - 18, y: omnibarFrame.maxY)
                                if let parentWindow = window.parent {
                                    origin = origin.flippedPointToBottomLeftOrigin(in: parentWindow)
                                }
                                window.setView(with: downloaderView, at: origin, fromTopLeft: true)
                                window.makeKey()
                                state.downloaderWindow = window
                            }
                        })
                        .frame(height: 32, alignment: .top)
                        .background(GeometryReader { proxy -> Color in
                            let rect = proxy.safeTopLeftGlobalFrame(in: nil)
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
                rightActionsView(containerGeometry: containerGeometry)
            }
            .padding(.leading, state.isFullScreen ? 0 : windowControlsWidth)
            .frame(height: 52, alignment: .top)
            .background(BeamColor.Generic.background.swiftUI
                            .shadow(color: barShadowColor, radius: 0, x: 0, y: 0.5)
            )
        }
        .frame(height: 52, alignment: .top)
    }

    private func hasWindowMovedSinceDragStart() -> Bool {
        guard let startDragWindowPosition = dragStartWindowPosition else { return false }
        let minimumDragThreshold: CGFloat = 5.0
        let currentPosition = state.windowFrame.origin
        let offset = max(abs(startDragWindowPosition.x - currentPosition.x), abs(startDragWindowPosition.y - currentPosition.y))
        return offset > minimumDragThreshold
    }

    // MARK: Actions
    func resetAutocompleteSelection() {
        autocompleteManager.resetAutocompleteSelection()
    }

    func goToJournal() {
        state.navigateToJournal(note: nil, clearNavigation: true)
    }

    func toggleReloadWeb() {
        let browserTabsManager = state.browserTabsManager
        if browserTabsManager.currentTab?.isLoading == true {
            browserTabsManager.stopLoadingCurrentTab()
        } else {
            browserTabsManager.reloadCurrentTab()
        }
    }

    func toggleMode() {
        state.toggleBetweenWebAndNote()
    }
}

private struct OmniBarReloadButton: View {
    @ObservedObject var currentTab: BrowserTab
    var action: () -> Void
    var body: some View {
        if currentTab.isLoading == true {
           return OmniBarButton(icon: "nav-refresh_stop", accessibilityId: "stopLoading", action: action)
        } else {
            return OmniBarButton(icon: "nav-refresh", accessibilityId: "refresh", action: action)
        }
    }
}

struct OmniBar_Previews: PreviewProvider {
    static let state = BeamState()
    static let focusedState = BeamState()
    static let beamData = BeamData()
    static let autocompleteManager = AutocompleteManager(with: beamData, searchEngine: GoogleSearch())
    static let browserTabManager = BrowserTabsManager(with: beamData, state: state)

    static var previews: some View {
        state.focusOmniBox = false
        focusedState.focusOmniBox = true
        focusedState.mode = .web
        let origin = BrowsingTreeOrigin.searchBar(query: "query")
        focusedState.browserTabsManager.currentTab = BrowserTab(state: focusedState, browsingTreeOrigin: origin, originMode: .today, note: BeamNote(title: "Note title"))
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
