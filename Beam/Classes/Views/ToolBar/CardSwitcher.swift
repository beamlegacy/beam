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
    var designV2 = false

    /// 0 is journal, 1-5 is cards, 6 is all cards
    @State private var hoveredIndex: Int?

    private func titleForNote(_ note: BeamNote) -> String {
        guard let journalDate = note.type.journalDate else {
            return note.title
        }
        return BeamDate.journalNoteTitle(for: journalDate, with: .medium)
    }

    private var v1Layout: some View {
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

    private var separator: some View {
        Separator()
            .frame(height: 16)
            .padding(.horizontal, 1.5)
            .blendModeLightMultiplyDarkScreen()
    }

    private var isAllCardsActive: Bool {
        state.mode == .page && state.currentPage?.id == .allCards
    }

    var body: some View {
        Group {
            if !designV2 {
                v1Layout
            } else {
                HStack(spacing: 0) {
                    OmniboxV2CapsuleButton(text: "Journal", isSelected: state.mode == .today) {
                        state.navigateToJournal(note: nil)
                    }
                    .fixedSize(horizontal: true, vertical: false)
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
                            OmniboxV2CapsuleButton(text: titleForNote(note), isSelected: isActive) {
                                state.navigateToNote(note)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .onHover { h in
                                if h {
                                    hoveredIndex = index + 1
                                }
                            }
                            separator
                                .opacity(hoveredIndex == index + 1 || hoveredIndex == index + 2 ? 0 : 1)
                        }
                    }
                    OmniboxV2CapsuleButton(text: "All cards", isSelected: isAllCardsActive) {
                        state.navigateToPage(.allCardsWindowPage)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .onHover { h in
                        if h {
                            hoveredIndex = recentsManager.recentNotes.count + 1
                        }
                    }
                }
            }
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
        return CardSwitcher(designV2: true)
            .environmentObject(state)
            .environmentObject(recentsManager)
            .frame(width: 700, height: 80)
    }
}
