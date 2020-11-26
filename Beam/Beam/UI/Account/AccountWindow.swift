import SwiftUI
import Cocoa
import Combine

class AccountWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        let accountDetail = AccountDetail()
        self.contentView = BeamHostingView(rootView: accountDetail)
        self.isMovableByWindowBackground = false
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }

        if delegate.accountWindow == self {
            delegate.accountWindow = nil
        }
    }
}
