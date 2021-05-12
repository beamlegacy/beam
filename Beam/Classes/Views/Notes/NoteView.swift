//
//  NoteView.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/09/2020.
//

import Foundation
import SwiftUI
import BeamCore

struct NoteView: View {
    @EnvironmentObject var state: BeamState

    static var topSpacingBeforeTitle: CGFloat {
        NoteHeaderView.topPadding
    }

    var note: BeamNote
    var onStartEditing: () -> Void = {}
    var leadingAlignement: CGFloat = 185
    var centerText: Bool
    var onScroll: ((CGPoint) -> Void)?
    @State private var scrollOffset: CGPoint = .zero

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
                openCard: { cardName in
                    state.navigateToNote(named: cardName)
                },
                onStartEditing: { onStartEditing() },
                onStartQuery: { textNode in
                    state.startQuery(textNode)
                },
                onScroll: { scrollPoint in
                    scrollOffset = scrollPoint
                    onScroll?(scrollPoint)
                },
                leadingAlignment: leadingAlignement,
                topOffset: 190,
                footerHeight: 60,
                centerText: centerText,
                showTitle: false
            )
            .accessibility(identifier: "noteView")
            .animation(nil)
            NoteHeaderView(note: note, documentManager: state.data.documentManager)
                .frame(maxWidth: BeamTextEdit.textWidth)
                .offset(x: -scrollOffset.x, y: -scrollOffset.y)
                .animation(nil)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
