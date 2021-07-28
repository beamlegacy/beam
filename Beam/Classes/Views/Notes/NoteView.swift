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
    var scrollToElementId: UUID?
    var onScroll: ((CGPoint) -> Void)?

    @State private var scrollOffset: CGPoint = .zero
    @State private var headerViewModel: NoteHeaderView.ViewModel?

    var body: some View {
        ZStack(alignment: .top) {
            BTextEditScrollable(
                note: note,
                data: state.data,
                openURL: { url, element in
                    if URL.urlSchemes.contains(url.scheme) {
                        state.createTabFromNote(note, element: element, withURL: url)
                    } else {
                        if let noteTitle = url.absoluteString.removingPercentEncoding {
                            state.navigateToNote(named: noteTitle)
                        }
                    }
                },
                openCard: { cardId, elementId in
                    state.navigateToNote(id: cardId, elementId: elementId)
                },
                onStartEditing: { onStartEditing?() },
                onStartQuery: { textNode, animated in
                    state.startQuery(textNode, animated: animated)
                },
                onScroll: { scrollPoint in
                    scrollOffset = scrollPoint
                    onScroll?(scrollPoint)
                },
                topOffset: NoteHeaderView.topPadding + 90,
                footerHeight: 60,
                leadingPercentage: leadingPercentage,
                centerText: centerText,
                showTitle: false,
                scrollToElementId: scrollToElementId
            )
            .accessibility(identifier: "noteView")
            .animation(nil)
            if let headerViewModel = headerViewModel {
                GeometryReader { reader in
                    NoteHeaderView(model: headerViewModel)
                        .frame(maxWidth: BeamTextEdit.textWidth)
                        .offset(x: centerText ? -scrollOffset.x : (containerGeometry.frame(in: .global).width - BeamTextEdit.textWidth) * (leadingPercentage / 100) - reader.frame(in: .global).minX, y: -scrollOffset.y)
                        .transition(.identity)
                        .animation(nil)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeamColor.Generic.background.swiftUI)
        .onReceive(Just(note)) { newNote in
            // Ideally we could use @StateObject in NoteHeaderView to let it manage its model
            // But its macOS > 11. So the parent need to own the model.
            guard headerViewModel?.note != newNote else { return }
            headerViewModel = NoteHeaderView.ViewModel(note: newNote, state: state, documentManager: state.data.documentManager)
        }
    }
}
