import SwiftUI
import Cocoa
import Combine

class DatabasesWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Databases"

        let databasesContentView = DatabasesContentView()
        self.contentView = BeamHostingView(rootView: databasesContentView)
        self.isMovableByWindowBackground = false
        observeCoredataDestroyedNotification()
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if delegate.databasesWindow == self {
            delegate.databasesWindow = nil
        }
    }

    private var cancellables = [AnyCancellable]()
    private func observeCoredataDestroyedNotification() {
        NotificationCenter.default.publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.contentView = BeamHostingView(rootView: DatabasesContentView())
            }
            .store(in: &cancellables)
    }
}
