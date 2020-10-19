import SwiftUI
import Cocoa
import Combine

class NotesWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Notes"

        let notesContentView = NotesContentView()
        self.contentView = BeamHostingView(rootView: notesContentView)
        self.isMovableByWindowBackground = false
        observeCoredataDestroyedNotification()
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if delegate.notesWindow == self {
            delegate.notesWindow = nil
        }
    }

    private var cancellables = [AnyCancellable]()
    private func observeCoredataDestroyedNotification() {
        let cancellable = NotificationCenter.default.publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.contentView = BeamHostingView(rootView: NotesContentView())
            }

        cancellables.append(cancellable)
    }
}
