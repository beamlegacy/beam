import SwiftUI
import Cocoa
import Combine

class DatabasesWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Databases"

        let databasesContentView = DatabasesContentView()
        contentView = BeamHostingView(rootView: databasesContentView)
        isMovableByWindowBackground = false
        delegate = self
        observeCoredataDestroyedNotification()
    }

    deinit {
        AppDelegate.main.databasesWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        cancellables.removeAll()
    }

    private var cancellables: [AnyCancellable] = []
    private func observeCoredataDestroyedNotification() {
        NotificationCenter.default.publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.contentView = BeamHostingView(rootView: DatabasesContentView())
            }
            .store(in: &cancellables)
    }
}
