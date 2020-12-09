import Foundation

extension AppDelegate {
    @IBAction func showAllNotes(_ sender: Any) {
        notesWindow = notesWindow ?? NotesWindow(
            contentRect: window.frame)
        notesWindow?.title = "All Notes"
        notesWindow?.center()
        notesWindow?.makeKeyAndOrderFront(window)
    }

    func showNote(_ note: Note) {
        let noteWindow = NoteWindow(note: note, contentRect: window.frame)
        noteWindow.center()
        noteWindow.makeKeyAndOrderFront(window)
    }

    func showNoteID(id: String) {
        guard let uuid = UUID(uuidString: id),
              let note = Note.fetchWithId(CoreDataManager.shared.mainContext, uuid) else { return }

        showNote(note)
    }

    func showNoteTitle(title: String) {
        guard let note = Note.fetchWithTitle(CoreDataManager.shared.mainContext, title) else { return }

        showNote(note)
    }

    func showBullet(id: String) {
        guard let uuid = UUID(uuidString: id),
              let bullet = Bullet.fetchWithId(CoreDataManager.shared.mainContext, uuid),
              let note = bullet.note else { return }

        showNote(note)
    }
}
