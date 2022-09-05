import SwiftUI
import Cocoa
import Combine

class FilesWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect, fileManager: BeamFileDBManager) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Files"

        let filesContentView = FilesContentView(fileManager: fileManager)
        contentView = BeamHostingView(rootView: filesContentView)
        isMovableByWindowBackground = false
        delegate = self
        observeCoredataDestroyedNotification(fileManager: fileManager)
    }

    deinit {
        AppDelegate.main.filesWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        cancellables.removeAll()
    }

    private var cancellables: [AnyCancellable] = []
    private func observeCoredataDestroyedNotification(fileManager: BeamFileDBManager) {
        NotificationCenter.default
            .publisher(for: .coredataDestroyed, object: nil)
            .sink { [weak self] _ in
                self?.contentView = BeamHostingView(rootView: FilesContentView(fileManager: fileManager))
            }
            .store(in: &cancellables)
    }
}
