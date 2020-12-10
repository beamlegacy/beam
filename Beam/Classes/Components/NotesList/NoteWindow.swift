import SwiftUI
import Cocoa
import Combine

class NoteWindow: NSWindow, NSWindowDelegate {
    init(note: Note, contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = note.title

        let noteDetail = NoteDetail(note: note)
        self.contentView = BeamHostingView(rootView: noteDetail)
        self.isMovableByWindowBackground = false
        observeCoredataDestroyedNotification()
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if let index = delegate.noteWindows.firstIndex(of: self) {
            delegate.noteWindows.remove(at: index)
        }
    }

    private var cancellables = [AnyCancellable]()
    private func observeCoredataDestroyedNotification() {
        let cancellable = NotificationCenter.default.publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.close()
            }

        cancellables.append(cancellable)
    }
}
