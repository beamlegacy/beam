import Foundation

extension AppDelegate {
    @IBAction func showAccount(_ sender: Any) {
        accountWindow = accountWindow ?? AccountWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 300))
        // TODO: loc
        accountWindow?.title = "Account"
        accountWindow?.center()
        accountWindow?.makeKeyAndOrderFront(window)
    }
}
