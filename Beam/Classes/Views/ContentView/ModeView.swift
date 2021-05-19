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
    @EnvironmentObject var data: BeamData
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    var containerGeometry: GeometryProxy
    @Binding var contentIsScrolled: Bool

    @State private var transitionModel = ModeTransitionModel()

    private var webContent: some View {
        VStack(spacing: 0) {
            BrowserTabBar(tabs: $browserTabsManager.tabs, currentTab: $browserTabsManager.currentTab)
                .zIndex(9)
            if let tab = browserTabsManager.currentTab {
                ZStack {
                    WebView(webView: tab.webView)

                    if data.showTabStats, let score = tab.browsingTree.current.score {
                        TabStats(score: score)
                    }

                    PointFrame(pointAndShootUI: tab.pointAndShoot.ui)
                    ShootFrame(pointAndShootUI: tab.pointAndShoot.ui)
                }.clipped()
            }
        }
        .transition(.webContentTransition)
    }

    private var noteContent: some View {
        Group {
            if let currentNote = state.currentNote {
                NoteView(note: currentNote, centerText: true) { scrollPoint in
                    contentIsScrolled = scrollPoint.y > NoteView.topSpacingBeforeTitle
                }
                .onAppear { contentIsScrolled = false }
                .transition(.noteContentTransition(transitionModel: transitionModel))
            }
        }
    }

    private func journalContent(containerGeometry: GeometryProxy) -> some View {
        JournalScrollView(axes: [.vertical],
                          showsIndicators: false,
                          proxy: containerGeometry) { scrollPoint in
            contentIsScrolled = scrollPoint.y >
                JournalScrollView.firstNoteTopOffset(forProxy: containerGeometry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear { contentIsScrolled = false }
        .onDisappear { data.reloadJournal() }
        .transition(.noteContentTransition(transitionModel: transitionModel))
        .accessibility(identifier: "journalView")
    }

    private var pageContent: some View {
        Group {
            if let page = state.currentPage {
                WindowPageView(page: page)
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
