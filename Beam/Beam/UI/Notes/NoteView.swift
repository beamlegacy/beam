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
    var note: Note
    var onStartEditing: () -> Void = {}
    var leadingAlignement = CGFloat(160)

    var body: some View {
        BTextEdit(note: note, openURL: { url in
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
        leadingAlignment: leadingAlignement
        )

    }
}
