import SwiftUI
import Cocoa
import Combine

class ConsoleWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "All Logs"

        let consoleContentView = ConsoleContentView()
        self.contentView = BeamHostingView(rootView: consoleContentView)
        self.isMovableByWindowBackground = false
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if delegate.consoleWindow == self {
            delegate.consoleWindow = nil
        }
    }
}
