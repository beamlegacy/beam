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
    @Environment(\.isMainWindow) private var isMainWindow: Bool
    @Environment(\.colorScheme) private var colorScheme

    var isAboveContent: Bool = false

    @State private var title = ""
    @State private var modifierFlagsPressed: NSEvent.ModifierFlags?
    @State private var showDownloadPanel: Bool = false
    @State private var dragStartWindowPosition: CGPoint?

    private var enableAnimations: Bool {
        !state.windowIsResizing
    }
    private let windowControlsWidth: CGFloat = 72
    private let boxHeightEditing: CGFloat = 40
    private var boxHeight: CGFloat {
        return isEditing ? boxHeightEditing : 32
    }

    private var isEditing: Bool {
        !state.useOmniboxV2 && state.focusOmniBox
    }

    private func setIsEditing(_ editing: Bool) {
        state.focusOmniBox = editing
        if editing {
            if state.mode == .web, let url = browserTabsManager.currentTab?.url?.absoluteString {
                autocompleteManager.resetQuery()
                autocompleteManager.searchQuerySelectedRange = url.wholeRange
                autocompleteManager.setQuery(url, updateAutocompleteResults: false)
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
        state.hasBrowserTabs && (state.useOmniboxV2 || !state.destinationCardIsFocused)
    }
    private var hasRightActions: Bool {
        state.useOmniboxV2 || showPivotButton || showDestinationNotePicker
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

    private var tapGestureWindowProof: some Gesture {
        // onTapGesture is triggered when moving NSWindow quickly.
        // Using a drag gesture instead to make sure the cursor/window hasn't moved.
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard dragStartWindowPosition == nil else { return }
                dragStartWindowPosition = state.windowFrame.origin
            }
            .onEnded { value in
                let windowHasMoved = hasWindowMovedSinceDragStart()
                dragStartWindowPosition = nil
                guard value.translation == .zero || !windowHasMoved else { return }
                setIsEditing(true)
            }
    }

    // MARK: Views
    private func fieldViewLegacy(containerGeometry: GeometryProxy) -> some View {
        OmniBarFieldBackground(isEditing: isEditing, isPressingCharacter: showPressedState, enableAnimations: enableAnimations) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    leftFieldActions
                    .animation(enableAnimations ? .easeInOut(duration: isEditing ? 0.1 : 0.3) : nil, value: isEditing)
                    .animation(nil)
                    centerSearchFieldView(containerGeometry: containerGeometry)
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
        .gesture(tapGestureWindowProof)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.trailing, isEditing ? 6 : 10)
        .padding(.top, isEditing ? 6 : 10)
        .animation(defaultAnimation)
        .animatableOffsetEffect(offset: CGSize(width: 0, height: showPressedState ? 3 : 0))
    }

    private func centerSearchFieldView(containerGeometry: GeometryProxy) -> some View {
        // Will be replaced by card switch and tabs v2
        GlobalCenteringContainer(enabled: !state.useOmniboxV2 && !isEditing && state.mode != .web, containerGeometry: containerGeometry) {
            OmniBarSearchField(isEditing: Binding<Bool>(get: { isEditing },
                                                        set: { setIsEditing($0) }),
                               modifierFlagsPressed: $modifierFlagsPressed,
                               enableAnimations: enableAnimations, designV2: false)
                .frame(maxHeight: .infinity)
                .offset(x: 0, y: autocompleteManager.animatedQuery != nil ? -12 : 0)
                .opacity(autocompleteManager.animatedQuery != nil ? 0 : 1)
                .overlay(cmdReturnAnimatedOverlay)
                .allowsHitTesting(!state.useOmniboxV2)
                .opacity(state.useOmniboxV2 && state.focusOmniBox ? 0.0 : 1.0)
                .opacity(isMainWindow ? 1 : (colorScheme == .dark ? 0.6 : 0.8))
        }
        .contentShape(Rectangle())
    }

    private func cardSwitcherView(containerGeometry: GeometryProxy) -> some View {
        GlobalCenteringContainer(enabled: true, containerGeometry: containerGeometry) {
            CardSwitcher(currentNote: state.currentNote, designV2: true)
                .frame(maxHeight: .infinity)
                .opacity(isMainWindow ? 1 : (colorScheme == .dark ? 0.6 : 0.8))
                .environmentObject(state.recentsManager)
        }
        .transition(.asymmetric(insertion: .opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
                                    .combined(with: .animatableOffset(offset: CGSize(width: 0, height: 8))
                                                .animation(BeamAnimation.spring(stiffness: 380, damping: 25))
                                             ),
                                removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
                                    .combined(with: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(BeamAnimation.spring(stiffness: 380, damping: 25).delay(0.03)))
                               ))
    }

    private var leftFieldActions: some View {
        HStack(spacing: 1) {
            if !isEditing {
                if state.mode != .today {
                    OmniboxV2ToolbarButton(icon: "nav-journal", action: goToJournal)
                        .accessibilityIdentifier("journal")
                        .animation(nil)
                }
                OmniboxV2ToolbarChevrons()
                    .animation(nil)
                if !state.useOmniboxV2 && state.mode == .web, let currentTab = browserTabsManager.currentTab {
                    OmniBarReloadButton(currentTab: currentTab, action: toggleReloadWeb)
                        .animation(nil)
                }
            }
        }
    }

    private var cmdReturnAnimatedOverlay: some View {
        Group {
            if let animatedQuery = autocompleteManager.animatedQuery {
                HStack(spacing: BeamSpacing._50) {
                    Icon(name: "field-search", color: BeamColor.Bluetiful.swiftUI)
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

    private func rightActionsView(containerGeometry: GeometryProxy) -> some View {
        Group {
            if hasRightActions {
                HStack(alignment: .center, spacing: BeamSpacing._100) {
                    if showDownloadsButton {
                        OmniBarDownloadButton(downloadManager: state.data.downloadManager, action: {
                            onDownloadButtonPressed(containerGeometry: containerGeometry)
                        })
                        .background(GeometryReader { proxy -> Color in
                            let rect = proxy.safeTopLeftGlobalFrame(in: nil)
                            let center = CGPoint(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height / 2)
                            state.downloadButtonPosition = center
                            return Color.clear
                        })
                    }
                    if state.useOmniboxV2 {
                        OmniboxV2ToolbarButton(icon: "nav-omnibox", action: {
                            setIsEditing(true)
                        })
                            .accessibilityIdentifier("nav-omnibox")
                    }
                    HStack(spacing: BeamSpacing._20) {
                        if showDestinationNotePicker, let currentTab = browserTabsManager.currentTab {
                            DestinationNotePicker(tab: currentTab)
                                .frame(height: 32, alignment: .top)
                        }
                        if showPivotButton {
                            OmniboxV2ToolbarButton(icon: state.mode == .web ? "nav-pivot_card" : "nav-pivot_web", action: toggleMode)
                                .accessibilityIdentifier(state.mode == .web ? "pivot-card" : "pivot-web")
                        }
                    }
                }
                .padding(.top, state.useOmniboxV2 ? 0 : BeamSpacing._100)
                .padding(.trailing, state.useOmniboxV2 ? 14 : BeamSpacing._100)
                .if(!state.useOmniboxV2) {
                    $0.frame(height: boxHeightEditing)
                    .animation(defaultAnimation)
                }
            }
        }
    }

    var body: some View {
        GeometryReader { containerGeometry in
            HStack(alignment: state.useOmniboxV2 ? .center : .top, spacing: 2) {
                if !state.useOmniboxV2 {
                    fieldViewLegacy(containerGeometry: containerGeometry)
                } else {
                    leftFieldActions
                    if state.mode == .web {
                        centerSearchFieldView(containerGeometry: containerGeometry)
                            .gesture(tapGestureWindowProof)
                            .padding(.horizontal, 14)
                            .transition(.asymmetric(insertion: .opacity.animation(BeamAnimation.easeInOut(duration: 0.12).delay(0.05))
                                                        .combined(with: .animatableOffset(offset: CGSize(width: 0, height: -8))
                                                                    .animation(BeamAnimation.spring(stiffness: 380, damping: 25).delay(0.05))
                                                                 ),
                                                    removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
                                                        .combined(with: .animatableOffset(offset: CGSize(width: 0, height: 8))
                                                                    .animation(BeamAnimation.spring(stiffness: 380, damping: 25))
                                                                 )
                                                   ))
                    } else {
                        cardSwitcherView(containerGeometry: containerGeometry)
                    }
                }
                rightActionsView(containerGeometry: containerGeometry)
            }
            .padding(.leading, 15 + (state.isFullScreen ? 0 : windowControlsWidth))
            .frame(height: 52, alignment: .top)
            .if(!state.useOmniboxV2) {
                $0.background(BeamColor.Generic.background.swiftUI
                                .shadow(color: barShadowColor, radius: 0, x: 0, y: 0.5)
                )
            }
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

    private func onDownloadButtonPressed(containerGeometry: GeometryProxy) {
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
    }
}

private struct OmniBarReloadButton: View {
    @ObservedObject var currentTab: BrowserTab
    var action: () -> Void
    var body: some View {
        if currentTab.isLoading == true {
            return OmniboxV2ToolbarButton(icon: "nav-refresh_stop", action: action).accessibilityIdentifier("stopLoading")
        } else {
            return OmniboxV2ToolbarButton(icon: "nav-refresh", action: action).accessibilityIdentifier("refresh")
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
