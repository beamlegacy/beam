//
//  OauthWebViewWindow.swift
//  Beam
//
//  Created by Stef Kors on 24/02/2022.
//

import SwiftUI
import Cocoa
import Combine
import OAuthSwift
import BeamCore

// MARK: - Oauth support
class OauthWebViewWindow: MinimalistWebViewWindow {
    let oauthController: OauthController

    override init(contentRect: NSRect, controller: MinimalistWebViewWindowController? = nil) {
        oauthController = OauthController(contentRect: contentRect)

        super.init(contentRect: contentRect, controller: oauthController)
        title = "Oauth"
        self.setFrameAutosaveName("Oauth")
    }

    deinit {
        AppDelegate.main.oauthWebViewWindow = nil
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
        AppDelegate.main.oauthWebViewWindow?.close()
    }

    func handle(_ url: URL) {
        self.openURL(url)
    }
}
