import SwiftUI
import Cocoa
import Combine

class DocumentsWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Documents"

        let documentsContentView = DocumentsContentView()
        self.contentView = BeamHostingView(rootView: documentsContentView)
        self.isMovableByWindowBackground = false
        observeCoredataDestroyedNotification()
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if delegate.documentsWindow == self {
            delegate.documentsWindow = nil
        }
    }

    private var cancellables = [AnyCancellable]()
    private func observeCoredataDestroyedNotification() {
        NotificationCenter.default.publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.contentView = BeamHostingView(rootView: DocumentsContentView())
            }
            .store(in: &cancellables)
    }
}
