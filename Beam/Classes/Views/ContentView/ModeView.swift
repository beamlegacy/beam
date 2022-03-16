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

    static var omniboxStartFadeOffset = CGFloat(20)
    static var omniboxEndFadeOffset = CGFloat(140)

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
                state.startShowingOmnibox()
                contentIsScrolled = false
            }
            .onDisappear(perform: {
                state.stopShowingOmnibox()
            })
            .animation(nil)
            .transition(.noteContentTransition(transitionModel: transitionModel))
            .accessibility(identifier: "journalView")
    }

    private func onScroll(_ scrollPoint: CGPoint, containerGeometry: GeometryProxy) {
        contentIsScrolled = scrollPoint.y + 52 >
        JournalScrollView.firstNoteTopOffset(forProxy: containerGeometry)

        CustomPopoverPresenter.shared.dismissPopovers()
        if state.showOmnibox &&
            state.autocompleteManager.searchQuery.isEmpty {
            if state.showOmnibox, scrollPoint.y >= Self.omniboxEndFadeOffset {
                state.stopFocusOmnibox()
                state.stopShowingOmnibox()
            }
        } else if scrollPoint.y < Self.omniboxEndFadeOffset {
            state.startShowingOmnibox()
            state.autocompleteManager.clearAutocompleteResults()
        }
    }

    private func onEndLiveScroll(_ scrollPoint: CGPoint) {
        if scrollPoint.y > Self.omniboxEndFadeOffset / 2, scrollPoint.y < Self.omniboxEndFadeOffset {
            guard let scrollView = state.cachedJournalStackView?.enclosingScrollView else {
                return
            }
            let clipView = scrollView.contentView
            let animationDuration = 0.3
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = animationDuration
            var p = clipView.bounds.origin
            p.y = Self.omniboxEndFadeOffset
            clipView.animator().setBoundsOrigin(p)
            scrollView.reflectScrolledClipView(clipView)
            NSAnimationContext.endGrouping()
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
