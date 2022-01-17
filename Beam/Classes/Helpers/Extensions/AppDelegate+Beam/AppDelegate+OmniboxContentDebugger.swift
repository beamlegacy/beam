import Foundation

extension AppDelegate {
    @IBAction func showOmnibarContentDebugger(_ sender: Any) {
        if let omniboxContentDebuggerWindow = omniboxContentDebuggerWindow {
            omniboxContentDebuggerWindow.makeKeyAndOrderFront(window)
            return
        }
        omniboxContentDebuggerWindow = OmniboxContentDebuggerWindow(contentRect: window?.frame ?? NSRect(origin: .zero, size: CGSize(width: 800, height: 600)))
        omniboxContentDebuggerWindow?.center()
        omniboxContentDebuggerWindow?.makeKeyAndOrderFront(window)
    }
}
