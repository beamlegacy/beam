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
    var leadingPercentage: CGFloat
    var centerText: Bool
    var initialFocusedState: NoteEditFocusedState?
    var onScroll: ((CGPoint) -> Void)?

    @State private var headerViewModel: NoteHeaderView.ViewModel?

    private var headerHeight: CGFloat {
        NoteHeaderView.topPadding + 90
    }

    var headerView: AnyView? {
        guard let headerViewModel = headerViewModel else {
            return nil
        }
        return AnyView(GeometryReader { geoProxy in
            let headerWidth = BeamTextEdit.textNodeWidth(for: geoProxy.size)
            let leadingPadding = centerText ? 0 : (geoProxy.size.width - headerWidth) * (leadingPercentage / 100)
            Group {
                NoteHeaderView(model: headerViewModel)
                    .frame(maxWidth: headerWidth)
            }
            .frame(maxWidth: .infinity, alignment: centerText ? .center : .bottomLeading)
            .padding(.leading, leadingPadding)
        }.frame(height: headerHeight))
    }

    var body: some View {
        ZStack(alignment: .top) {
            BTextEditScrollable(
                note: note,
                data: state.data,
                openURL: { url, element in
                    state.handleOpenUrl(url, note: note, element: element)
                },
                openCard: { cardId, elementId, unfold in
                    state.navigateToNote(id: cardId, elementId: elementId, unfold: unfold ?? false)
                },
                startQuery: { textNode, animated in
                    state.startQuery(textNode, animated: animated)
                },
                onStartEditing: { onStartEditing?() },
                onFocusChanged: { elementId, cursorPosition in
                    state.updateNoteFocusedState(note: note, focusedElement: elementId, cursorPosition: cursorPosition)
                },
                onScroll: onScroll,
                topOffset: headerHeight,
                footerHeight: 60,
                leadingPercentage: leadingPercentage,
                centerText: centerText,
                showTitle: false,
                initialFocusedState: initialFocusedState,
                headerView: headerView
            )
            .accessibility(identifier: "noteView")
            .animation(nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeamColor.Generic.background.swiftUI)
        .onReceive(Just(note)) { newNote in
            // Ideally we could use @StateObject in NoteHeaderView to let it manage its model
            // But its macOS > 11. So the parent need to own the model.
            guard headerViewModel?.note != newNote else { return }
            headerViewModel = NoteHeaderView.ViewModel(note: newNote, state: state, documentManager: state.data.documentManager)
        }
        .onReceive(note.changed.debounce(for: .seconds(10), scheduler: RunLoop.main)) { changed in
            let (_, change) = changed
            guard change != .meta else { return }
            guard note.publicationStatus != .unpublished else { return }
            BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, documentManager: state.data.documentManager)
        }
    }
}
