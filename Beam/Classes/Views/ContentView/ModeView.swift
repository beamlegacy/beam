//
//  ModeView.swift
//  Beam
//
//  Created by Remi Santos on 18/05/2021.
//

import SwiftUI
import BeamCore

struct ModeView: View {

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    var containerGeometry: GeometryProxy
    @Binding var contentIsScrolled: Bool

    @State private var transitionModel = ModeTransitionModel()
    private let cardScrollViewTopInset: CGFloat = Toolbar.height

    private var webContent: some View {
        ZStack(alignment: .top) {
            if let tab = browserTabsManager.currentTab {
                EnhancedWebView(tab: tab).clipped()
            }
        }
        .onAppear { contentIsScrolled = false }
        .transition(.webContentTransition(windowInfo.windowIsResizing))
    }

    private var noteContent: some View {
        Group {
            if let currentNote = state.currentNote {
                NoteView(note: currentNote, containerGeometry: containerGeometry, topInset: cardScrollViewTopInset, leadingPercentage: PreferencesManager.editorLeadingPercentage,
                         centerText: false, initialFocusedState: state.notesFocusedStates.currentFocusedState) { scrollPoint in
                    contentIsScrolled = scrollPoint.y > NoteView.topSpacingBeforeTitle - cardScrollViewTopInset
                    CustomPopoverPresenter.shared.dismissPopovers()
                }
                .onAppear { contentIsScrolled = false }
                .transition(.noteContentTransition(transitionModel: transitionModel))
            }
        }
    }

    static func omniboxStartFadeOffsetFor(height: CGFloat) -> CGFloat {
        0.2 * (OmniboxContainer.firstNoteTopOffsetForJournal(height: height) - OmniboxContainer.topOffsetForJournal(height: height))

    }
    static func omniboxEndFadeOffsetFor(height: CGFloat) -> CGFloat {
        OmniboxContainer.firstNoteTopOffsetForJournal(height: height) - OmniboxContainer.topOffsetForJournal(height: height)

    }
    var omniboxEndFadeOffset: CGFloat { Self.omniboxEndFadeOffsetFor(height: containerGeometry.size.height) }
    var omniboxStartFadeOffset: CGFloat { Self.omniboxStartFadeOffsetFor(height: containerGeometry.size.height) }

    private func journalContent(containerGeometry: GeometryProxy) -> some View {
        JournalScrollView(axes: [.vertical],
                          showsIndicators: false,
                          topInset: cardScrollViewTopInset,
                          proxy: containerGeometry,
                          onScroll: { scrollPoint in
            onScroll(scrollPoint, containerGeometry: containerGeometry)
        }, onEndLiveScroll: { scrollPoint in
            onEndLiveScroll(scrollPoint)
        })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear {
                DispatchQueue.main.async {
                    state.data.reloadAllEvents()
                }
                contentIsScrolled = false
                guard !transitionModel.isTransitioning && state.mode == .today else { return }
                state.startShowingOmniboxInJournal()
                state.autocompleteManager.clearAutocompleteResults()
            }
            .onChange(of: transitionModel.isTransitioning) { isTransitioning in
                guard !isTransitioning && state.mode == .today else { return }
                state.startShowingOmniboxInJournal()
                state.autocompleteManager.clearAutocompleteResults()
            }
            .onDisappear {
                state.stopShowingOmniboxInJournal()
            }
            .animation(nil)
            .transition(.noteContentTransition(transitionModel: transitionModel))
            .accessibility(identifier: "journalView")
    }

    private func onScroll(_ scrollPoint: CGPoint, containerGeometry: GeometryProxy) {
        let scrollOffset = scrollPoint.y + cardScrollViewTopInset
        contentIsScrolled = scrollOffset >
        JournalScrollView.firstNoteTopOffset(forProxy: containerGeometry)

        CustomPopoverPresenter.shared.dismissPopovers()
        guard !transitionModel.isTransitioning else { return }
        if state.omniboxInfo.isShownInJournal && (!state.omniboxInfo.isFocused || state.omniboxInfo.wasFocusedFromJournalTop) {
            if scrollOffset >= omniboxEndFadeOffset {
                state.stopFocusOmnibox()
                state.stopShowingOmniboxInJournal()
                state.autocompleteManager.resetQuery()
                state.autocompleteManager.clearAutocompleteResults()
            }
        } else if scrollOffset < omniboxEndFadeOffset {
            state.startShowingOmniboxInJournal()
        }
    }

    private func onEndLiveScroll(_ scrollPoint: CGPoint) {
        let scrollOffset = scrollPoint.y + cardScrollViewTopInset
        if scrollOffset < omniboxEndFadeOffset {
            guard let stackView = state.cachedJournalStackView else { return }
            if scrollOffset > (omniboxEndFadeOffset + omniboxStartFadeOffset) * 0.5 {
                stackView.scroll(toVerticalOffset: omniboxEndFadeOffset)
            } else {
                stackView.scrollToTop(animated: true)
            }

        }
    }

    private var pageContent: some View {
        Group {
            if let page = state.currentPage {
                WindowPageView(page: page)
                    .padding(.top, cardScrollViewTopInset)
                    .transition(.identity)
            }
        }
    }

    var body: some View {
        ZStack {
            Group {
                switch state.mode {
                case .note:
                    noteContent
                case .today:
                    journalContent(containerGeometry: containerGeometry)
                case .page:
                    pageContent
                case .web:
                    webContent
                        // zIndex needed for transitions animations
                        // otherwise the appearing view is always on top
                        .zIndex(4)
                }
            }
        }
        .onAppear {
            transitionModel.state = state
        }
    }
}
