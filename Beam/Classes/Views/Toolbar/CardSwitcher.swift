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

    private let maxNoteTitleLength = 40

    private func titleForNote(_ note: BeamNote) -> String {
        guard let journalDate = note.type.journalDate else {
            return truncatedTitle(note.title)
        }
        return truncatedTitle(BeamDate.journalNoteTitle(for: journalDate, with: .medium))
    }

    /// Manually truncating text because using maxWidth in SwiftUI makes the Text spread
    private func truncatedTitle(_ title: String) -> String {
        guard title.count > maxNoteTitleLength else { return title }
        return title.prefix(maxNoteTitleLength).trimmingCharacters(in: .whitespaces) + "…"
    }

    private var separator: some View {
        Separator(rounded: true, color: BeamColor.ToolBar.horizontalSeparator)
            .frame(height: 16)
            .padding(.horizontal, 1.5)
            .blendModeLightMultiplyDarkScreen()
    }

    private var isAllNotesActive: Bool {
        state.mode == .page && state.currentPage?.id == .allNotes
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ToolbarCapsuleButton(iconName: "editor-journal", text: "Journal", isSelected: state.mode == .today) {
                state.navigateToJournal(note: nil)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
            .tooltipOnHover(Shortcut.AvailableShortcut.showJournal.keysDescription)
            .accessibilityIdentifier("card-switcher-journal")

            ToolbarCapsuleButton(iconName: "editor-allnotes", text: "All Notes", isSelected: isAllNotesActive) {
                state.navigateToPage(.allNotesWindowPage)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
            .tooltipOnHover(Shortcut.AvailableShortcut.showAllNotes.keysDescription)
            .accessibilityIdentifier("card-switcher-all-cards")
            .offset(x: -3, y: 0)

            Spacer(minLength: 2)
            separator
            Spacer(minLength: 5)

            if recentsManager.recentNotes.count > 0 {
                ForEach(Array(recentsManager.recentNotes.enumerated()), id: \.1.id) { index, note in
                    let isToday = state.mode == .today
                    let isActive = !isToday && note.id == currentNote?.id
                    let text = titleForNote(note)
                    ToolbarCapsuleButton(text: text, isSelected: isActive) {
                        state.navigateToNote(note)
                    }
                    .accessibilityIdentifier("card-switcher")
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct CardSwitcher_Previews: PreviewProvider {
    static let state = BeamState()
    static var previews: some View {
        let recentsManager = state.recentsManager
        state.mode = .today
        recentsManager.currentNoteChanged(BeamNote(title: "Note D"))
        recentsManager.currentNoteChanged(BeamNote(title: "Note C"))
        recentsManager.currentNoteChanged(BeamNote(title: "Note B"))
        recentsManager.currentNoteChanged(BeamNote(title: "Note A"))
        return CardSwitcher()
            .environmentObject(state)
            .environmentObject(recentsManager)
            .frame(width: 700, height: 80)
    }
}
