import SwiftUI
import Cocoa
import Combine
import OAuthSwift
import BeamCore

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

// MARK: - Oauth support
class OauthWindow: MinimalistWebViewWindow {
    let oauthController: OauthController

    override init(contentRect: NSRect, controller: MinimalistWebViewWindowController? = nil) {
        oauthController = OauthController(contentRect: contentRect)

        super.init(contentRect: contentRect, controller: oauthController)
        title = "Oauth"
        self.setFrameAutosaveName("Oauth")
    }

    deinit {
        AppDelegate.main.oauthWindow = nil
    }
}

class OauthController: MinimalistWebViewWindowController, OAuthSwiftURLHandlerType {

    deinit {
        Logger.shared.logDebug("deinit OauthController", category: .oauth)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Google doesn't allow our own scheme :(
        let oauthBeamSchemes = [EnvironmentVariables.Oauth.Google.callbackURL.components(separatedBy: ":").first,
                                EnvironmentVariables.Oauth.Github.callbackURL.components(separatedBy: ":").first]

        if let url = navigationAction.request.url, let scheme = url.scheme, oauthBeamSchemes.contains(scheme) {
            OAuthSwift.handle(url: url)
            dismissWebViewController()
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // If having NSURLErrorDomain error -999 see :
        // https://developer.apple.com/documentation/foundation/1508628-url_loading_system_error_codes/nsurlerrorcancelled

        Logger.shared.logError(error.localizedDescription, category: .oauth)
        dismissWebViewController()

        if let url = url {
            OAuthSwift.handle(url: url)
        }

        UserAlert.showError(error: error)
    }

    private func dismissWebViewController() {
        AppDelegate.main.oauthWindow?.close()
    }

    func handle(_ url: URL) {
        self.openURL(url)
    }
}
