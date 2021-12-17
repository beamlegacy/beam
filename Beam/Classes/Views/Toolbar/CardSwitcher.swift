//
//  CardSwitcher.swift
//  Beam
//
//  Created by Remi Santos on 11/05/2021.
//

import SwiftUI
import BeamCore

struct CardSwitcher: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var recentsManager: RecentsManager

    var currentNote: BeamNote?

    /// 0 is journal, 1-5 is cards, 6 is all cards
    @State private var hoveredIndex: Int?

    private func titleForNote(_ note: BeamNote) -> String {
        guard let journalDate = note.type.journalDate else {
            return note.title
        }
        return BeamDate.journalNoteTitle(for: journalDate, with: .medium)
    }

    private var separator: some View {
        Separator(rounded: true, color: BeamColor.ToolBar.horizontalSeparator)
            .frame(height: 16)
            .padding(.horizontal, 1.5)
            .blendModeLightMultiplyDarkScreen()
    }

    private var isAllCardsActive: Bool {
        state.mode == .page && state.currentPage?.id == .allCards
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ToolbarCapsuleButton(text: "Journal", isSelected: state.mode == .today) {
                state.navigateToJournal(note: nil)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
            .onHover { h in
                if h {
                    hoveredIndex = 0
                }
            }
            separator
                .opacity(hoveredIndex != 0 && hoveredIndex != 1 ? 1 : 0)
            if recentsManager.recentNotes.count > 0 {
                ForEach(Array(recentsManager.recentNotes.enumerated()), id: \.1.id) { index, note in
                    let isToday = state.mode == .today
                    let isActive = !isToday && note.id == currentNote?.id
                    ToolbarCapsuleButton(text: titleForNote(note), isSelected: isActive) {
                        state.navigateToNote(note)
                    }
                    .onHover { h in
                        if h {
                            hoveredIndex = index + 1
                        }
                    }
                    separator
                        .opacity(hoveredIndex == index + 1 || hoveredIndex == index + 2 ? 0 : 1)
                }
            }
            ToolbarCapsuleButton(text: "All Cards", isSelected: isAllCardsActive) {
                state.navigateToPage(.allCardsWindowPage)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
            .onHover { h in
                if h {
                    hoveredIndex = recentsManager.recentNotes.count + 1
                }
            }
            Spacer(minLength: 0)
        }
        .onHover { h in
            if !h {
                hoveredIndex = -1
            }
        }
    }
}

struct CardSwitcher_Previews: PreviewProvider {
    static let state = BeamState()
    static var previews: some View {
        let recentsManager = state.recentsManager
        state.mode = .today
        recentsManager.currentNoteChanged(BeamNote(title: "Card D"))
        recentsManager.currentNoteChanged(BeamNote(title: "Card C"))
        recentsManager.currentNoteChanged(BeamNote(title: "Card B"))
        recentsManager.currentNoteChanged(BeamNote(title: "Card A"))
        return CardSwitcher()
            .environmentObject(state)
            .environmentObject(recentsManager)
            .frame(width: 700, height: 80)
    }
}
