import SwiftUI
import Cocoa
import Combine

class DocumentsWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Documents"

        let documentsContentView = DocumentsContentView()
        contentView = BeamHostingView(rootView: documentsContentView)
        isMovableByWindowBackground = false
        delegate = self
        observeCoredataDestroyedNotification()
    }

    deinit {
        AppDelegate.main.documentsWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        cancellables.removeAll()
    }

    private var cancellables: [AnyCancellable] = []
    private func observeCoredataDestroyedNotification() {
        NotificationCenter.default
            .publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.contentView = BeamHostingView(rootView: DocumentsContentView())
            }
            .store(in: &cancellables)
    }
}
