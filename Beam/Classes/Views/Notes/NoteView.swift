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
    var showTitle: Bool
    var scrollable: Bool

    var body: some View {
        ZStack {
            if scrollable {
                BTextEditScrollable(
                    note: note,
                    data: state.data,
                    openURL: { url in
                    if ["http", "https"].contains(url.scheme) {
                        state.createTab(withURL: url, originalQuery: state.currentNote?.title ?? "")
                    } else {
                        if let noteName = url.absoluteString.removingPercentEncoding {
                            state.navigateToNote(named: noteName)
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
                showTitle: showTitle
                ).animation(.none)
            } else {
                BTextEdit(
                    note: note,
                    data: state.data,
                    openURL: { url in
                    if ["http", "https"].contains(url.scheme) {
                        state.createTab(withURL: url, originalQuery: state.currentNote?.title ?? "")
                    } else {
                        if let noteName = url.absoluteString.removingPercentEncoding {
                            _ = state.navigateToNote(named: noteName)
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
                footerHeight: 100,
                showTitle: showTitle
                )
                .frame(maxWidth: .infinity, idealHeight: 300)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
