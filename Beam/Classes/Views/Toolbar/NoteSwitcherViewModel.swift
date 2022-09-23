//
//  NoteSwitcherViewModel.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 19/09/2022.
//

import Foundation
import BeamCore

struct NoteSwitcherElement: Hashable, Identifiable {
    internal init(note: BeamNote, isOverflowing: Bool = false) {
        self.note = note
        self.isOverflowing = isOverflowing
        self.displayTitle = Self.titleForNote(note)
    }

    let displayTitle: String
    let note: BeamNote
    var isOverflowing = false
    var id: UUID {
        note.id
    }

    private static func titleForNote(_ note: BeamNote) -> String {
        guard let journalDate = note.type.journalDate else {
            return truncatedTitle(note.title)
        }
        return truncatedTitle(BeamDate.journalNoteTitle(for: journalDate, with: .medium))
    }

    private static let maxNoteTitleLength = 40

    /// Manually truncating text because using maxWidth in SwiftUI makes the Text spread
    private static func truncatedTitle(_ title: String) -> String {
        guard title.count > maxNoteTitleLength else { return title }
        return title.prefix(maxNoteTitleLength).trimmingCharacters(in: .whitespaces) + "…"
    }
}

class NoteSwitcherViewModel: ObservableObject {

    @Published var elements: [NoteSwitcherElement]

    init(notes: [BeamNote]) {
        elements = notes.map({ NoteSwitcherElement(note: $0) })
    }

    func setNotes(_ notes: [BeamNote]) {
        elements = notes.map({ NoteSwitcherElement(note: $0) })
    }

    func dislayAllElements() {
        for (offset, var element) in elements.enumerated() {
            element.isOverflowing = false
            updateElement(element, at: offset)
        }
    }

    func updateElement(_ element: NoteSwitcherElement, at index: Int) {
        guard index < elements.count else { return }
        elements[index] = element
    }
}
