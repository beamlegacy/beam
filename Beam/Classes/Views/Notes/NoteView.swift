//
//  NoteView.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/09/2020.
//

import Foundation
import SwiftUI

struct NoteView: View {
    @EnvironmentObject var state: BeamState

    var note: BeamNote
    var onStartEditing: () -> Void = {}
    var leadingAlignement = CGFloat(185)
    var topOffset: CGFloat = CGFloat(45)
    var showTitle: Bool
    var scrollable: Bool
    var centerText: Bool

    var body: some View {
        ZStack {
            if scrollable {
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
                    leadingAlignment: leadingAlignement,
                    footerHeight: 60,
                    centerText: centerText,
                    showTitle: showTitle
                )
                .accessibility(identifier: "noteView")
                .animation(.none)
            } else {
                BTextEdit(
                    note: note,
                    data: state.data,
                    openURL: { url, element in
                        if URL.urlSchemes.contains(url.scheme) {
                            state.createTabFromNote(note, element: element, withURL: url)
                        } else {
                            if let noteTitle = url.absoluteString.removingPercentEncoding {
                                _ = state.navigateToNote(named: noteTitle)
                            }
                        }
                    },
                    openCard: { cardName in
                        _ = state.navigateToNote(named: cardName)
                    },
                    onStartEditing: { onStartEditing() },
                    onStartQuery: { textNode in
                        state.startQuery(textNode)
                    },
                    leadingAlignment: leadingAlignement,
                    topOffset: topOffset,
                    footerHeight: 25,
                    centerText: centerText,
                    showTitle: showTitle
                )
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
