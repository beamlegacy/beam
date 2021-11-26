import SwiftUI
import Cocoa
import Combine

class FilesWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Files"

        let filesContentView = FilesContentView()
        contentView = BeamHostingView(rootView: filesContentView)
        isMovableByWindowBackground = false
        delegate = self
        observeCoredataDestroyedNotification()
    }

    deinit {
        AppDelegate.main.filesWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        cancellables.removeAll()
    }

    private var cancellables: [AnyCancellable] = []
    private func observeCoredataDestroyedNotification() {
        NotificationCenter.default
            .publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.contentView = BeamHostingView(rootView: FilesContentView())
            }
            .store(in: &cancellables)
    }
}
