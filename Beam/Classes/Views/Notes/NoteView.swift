//
//  NoteView.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/09/2020.
//

import Foundation
import SwiftUI
import BeamCore
import Combine

struct NoteView: View {

    @EnvironmentObject var state: BeamState

    static var topSpacingBeforeTitle: CGFloat {
        NoteHeaderView.topPadding
    }

    var note: BeamNote
    var containerGeometry: GeometryProxy
    var onStartEditing: (() -> Void)?
    var topInset: CGFloat
    var leadingPercentage: CGFloat
    var centerText: Bool
    var initialFocusedState: NoteEditFocusedState?
    var onScroll: ((CGPoint) -> Void)?

    @StateObject private var headerViewModel = NoteHeaderView.ViewModel()
    @StateObject private var headerLayoutModel = HeaderViewContainer.LayoutModel()
    @State private var searchViewModel: SearchViewModel?
    @State private var tabGroups: [UUID] = []

    private var headerHeight: CGFloat {
        NoteHeaderView.topPadding + 90
    }

    private var topOffset: CGFloat {
        var tabGroupSpace: CGFloat = 0
        if !headerViewModel.tabGroupObjects.isEmpty {
            let numberOfLines = (CGFloat(headerViewModel.tabGroupObjects.count) / 4.0).rounded(.up)
            let lineSpacing = 6.0
            let lineHeight = EditorTabGroupView.height + lineSpacing
            let topSpace = 45.0

            tabGroupSpace = numberOfLines * lineHeight + topSpace
        }
        return headerHeight + tabGroupSpace
    }

    var body: some View {
        ZStack(alignment: .top) {
            BTextEditScrollable(
                note: note,
                state: state,
                openURL: { url, element, inBackground in
                    state.handleOpenUrl(url, note: note, element: element, inBackground: inBackground)
                },
                openCard: { cardId, elementId, unfold in
                    state.navigateToNote(id: cardId, elementId: elementId, unfold: unfold ?? false)
                },
                startQuery: { textNode, animated in
                    state.startQuery(textNode, animated: animated)
                },
                onStartEditing: { onStartEditing?() },
                onFocusChanged: { [weak state] elementId, cursorPosition in
                    state?.updateNoteFocusedState(note: note, focusedElement: elementId, cursorPosition: cursorPosition)
                },
                onScroll: onScroll,
                onSearchToggle: { search in
                    self.searchViewModel = search
                },
                topOffset: topOffset,
                scrollViewTopInset: topInset,
                footerHeight: 60,
                leadingPercentage: leadingPercentage,
                centerText: centerText,
                showTitle: false,
                initialFocusedState: initialFocusedState,
                initialScrollOffset: state.lastScrollOffset[note.id],
                headerView: {
                    HeaderViewContainer(layoutModel: headerLayoutModel, headerViewModel: headerViewModel)
                        .frame(height: topOffset)
                        .frame(maxWidth: .infinity)
                }
            )
            .accessibility(identifier: "noteView")
            .animation(nil)
        }
        .overlay(searchView, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeamColor.Generic.background.swiftUI)
        .onReceive(Just(note)) { newNote in
            guard headerViewModel.note != newNote else { return }
            headerLayoutModel.centerText = centerText
            headerLayoutModel.leadingPercentage = leadingPercentage
            headerViewModel.state = state
            headerViewModel.note = newNote
            tabGroups = newNote.tabGroups
            headerViewModel.setTabGroups(with: newNote.tabGroups)
        }
        .onReceive(note.changed.debounce(for: .seconds(10), scheduler: RunLoop.main)) { changed in
            let (_, change) = changed
            guard change != .meta else { return }
            guard note.publicationStatus != .unpublished else { return }
            BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, publicationGroups: note.publicationStatus.publicationGroups)
        }
        .onReceive(note.changed) { changed in
            let (element, _) = changed
            if let note = element as? BeamNote, tabGroups != note.tabGroups {
                tabGroups = note.tabGroups
                headerViewModel.setTabGroups(with: note.tabGroups)
            }
        }
    }

    @ViewBuilder var searchView: some View {
        if let search = self.searchViewModel {
            GeometryReader { proxy in
                HStack(alignment: .top, spacing: 12) {
                    Spacer()
                    SearchInContentView(viewModel: search)
                        .padding(.top, 10)
                    SearchLocationView(viewModel: search, height: proxy.size.height)
                        .frame(width: 8)
                        .padding(.trailing, 10)
                }
                .padding(.top, topInset)
            }
        }
    }
}

private struct HeaderViewContainer: View {

    class LayoutModel: ObservableObject {
        @Published var centerText: Bool = false
        @Published var leadingPercentage: CGFloat = 0
    }

    @ObservedObject var layoutModel: HeaderViewContainer.LayoutModel
    @ObservedObject var headerViewModel: NoteHeaderView.ViewModel
    @EnvironmentObject var state: BeamState

    var body: some View {
        GeometryReader { geoProxy in
            let headerWidth = BeamTextEdit.textNodeWidth(for: geoProxy.size)
            let leadingPadding = layoutModel.centerText ? 0 : (geoProxy.size.width - headerWidth) * (layoutModel.leadingPercentage / 100)
            Group {
                NoteHeaderView(model: headerViewModel, pinnedManager: state.data.pinnedManager)
                    .frame(maxWidth: headerWidth)
            }
            .frame(maxWidth: .infinity, alignment: layoutModel.centerText ? .center : .bottomLeading)
            .padding(.leading, leadingPadding)
        }
    }
}
