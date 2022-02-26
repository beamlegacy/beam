import SwiftUI

class MinimalistWebViewWindow: NSWindow, NSWindowDelegate {
    let controller: MinimalistWebViewWindowController
    init(contentRect: NSRect, controller: MinimalistWebViewWindowController? = nil) {
        self.controller = controller ?? .init(contentRect: contentRect)
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "Beam"

        self.center()
        self.setFrameAutosaveName("Beam")
        self.isReleasedWhenClosed = true

        self.contentView = self.controller.webView
    }

    deinit {
        AppDelegate.main.minimalistWebWindow = nil
    }
}

class MinimalistWebViewWindowController: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    var url: URL?

    init(contentRect: NSRect) {
        webView = WKWebView(frame: contentRect)
        webView.loadHTMLString("<html><body><p>Loading...</p></body></html>", baseURL: nil)
    }

    func openURL(_ url: URL) {
        webView.navigationDelegate = self
        self.url = url

        let request = URLRequest(url: url)
        webView.load(request)
    }
}
