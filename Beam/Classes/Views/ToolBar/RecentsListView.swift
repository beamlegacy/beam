//
//  RecentsListView.swift
//  Beam
//
//  Created by Remi Santos on 11/05/2021.
//

import SwiftUI
import BeamCore

struct RecentsListView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var recentsManager: RecentsManager

    var currentNote: BeamNote?

    private func titleForNote(_ note: BeamNote) -> String {
        guard let journalDate = note.type.journalDate else {
            return note.title
        }
        return BeamDate.journalNoteTitle(for: journalDate, with: .medium)
    }

    var body: some View {
        HStack(spacing: 6) {
            ButtonLabel("Journal", state: state.mode == .today ? .active : .normal) {
                state.navigateToJournal(note: nil, clearNavigation: false)
            }
            .fixedSize(horizontal: true, vertical: false)
            if recentsManager.recentNotes.count > 0 {
                Separator()
                ForEach(recentsManager.recentNotes) { note in
                    let isToday = state.mode == .today
                    let isActive = !isToday && note.id == currentNote?.id
                    ButtonLabel(titleForNote(note), state: isActive ? .active : .normal, action: {
                        state.navigateToNote(id: note.id)
                    })
                }
            }
        }.animation(nil)
    }
}
