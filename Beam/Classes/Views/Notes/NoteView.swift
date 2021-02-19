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
    var centerText: Bool

    let urlSchemes: [String?] = ["http", "https"]

    var body: some View {
        ZStack {
            if scrollable {
                BTextEditScrollable(
                    note: note,
                    data: state.data,
                    openURL: { url in
                    if urlSchemes.contains(url.scheme) {
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
                centerText: centerText,
                showTitle: showTitle
                )
                .accessibility(identifier: "noteView")
                .animation(.none)
            } else {
                BTextEdit(
                    note: note,
                    data: state.data,
                    openURL: { url in
                    if urlSchemes.contains(url.scheme) {
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
                footerHeight: 25,
                centerText: centerText,
                showTitle: showTitle
                )
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
