//
//  WebKitNavigationHandler.swift
//  Beam
//
//  Created by Stef Kors on 24/02/2022.
//

import Foundation
import BeamCore
import WebKit

class WebKitNavigationHandler: NSObject, WKNavigationDelegate {
    /// The target WebPage. Used as a target for where new Tabs will be created
    weak var page: WebPage? {
        didSet {
            webViewController = page?.webViewNavigationHandler
        }
    }

    weak var webViewController: WebViewNavigationHandler?
}

// MARK: - Allowing or Denying Navigation Requests
extension WebKitNavigationHandler {
    /// Asks the delegate for permission to navigate to new content based on the specified action information.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        webViewController?.webView(webView, willPerformNavigationAction: navigationAction)
        decisionHandler(.allow)
    }

    /// Asks the delegate for permission to navigate to new content based on the specified preferences and action information.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        // Return early if navigation action is a download action
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download, preferences)
            return
        }

        webViewController?.webView(webView, willPerformNavigationAction: navigationAction)

        // Handle Deep Linking to External Applications
        let deeplinkHandler = ExternalDeeplinkHandler(request: navigationAction.request)
        if deeplinkHandler.isDeeplink() {
            decisionHandler(.cancel, preferences)
            // Open Alert with userprompt to open External Application
            if deeplinkHandler.shouldOpenDeeplink(),
                let targetURL = navigationAction.request.url {
                NSWorkspace.shared.open(targetURL)
            }
            return
        }

        // Handle opening the targetURL in a newTab if all conditions are met
        if openNewTab(navigationAction) {
            decisionHandler(.cancel, preferences)
        }

        decisionHandler(.allow, preferences)
    }

    /// Asks the delegate for permission to navigate to new content after the response to the navigation request is known.
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        if let response = navigationResponse.response as? HTTPURLResponse, webView.url == response.url {
            page?.responseStatusCode = response.statusCode
        }

        if let internalURL = NavigationRouter.responseShouldRedirectToInternalURL(navigationResponse.response) {
            // Cancel navigation and redirect to the internal URL equivalent.
            // Because we cancel this navigation, only this internal URL will be added to the web view history, not the
            // original one.
            decisionHandler(.cancel)

            let request = URLRequest(url: internalURL)
            webView.load(request)

            return
        }

        decisionHandler(.allow)
    }

}

// MARK: - Tracking the Load Progress of a Request
extension WebKitNavigationHandler {

    /// Tells the delegate that navigation from the main frame has started.
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

    /// Tells the delegate that the web view received a server redirect for a request.
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) { }

    /// Tells the delegate that the web view has started to receive content for the main frame.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let webviewUrl = webView.url else {
            return // webview probably failed to load
        }
        webViewController?.webView(webView, didReachURL: webviewUrl)
    }

    /// Tells the delegate that navigation is complete.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        webViewController?.webView(webView, didFinishNavigationToURL: url, source: .webKit)
    }

}

// MARK: - Responding to Authentication Challenges
extension WebKitNavigationHandler {

    /// Asks the delegate to respond to an authentication challenge.
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        switch authenticationMethod {
        case NSURLAuthenticationMethodDefault,
            NSURLAuthenticationMethodHTTPBasic,
            NSURLAuthenticationMethodHTTPDigest:
            let viewModel  = AuthenticationViewModel(challenge: challenge, onValidate: { [weak self] username, password, savePassword in
                NSApp.mainWindow?.makeFirstResponder(nil)
                let credential = URLCredential(user: username, password: password, persistence: .forSession)
                completionHandler(.useCredential, credential)
                if savePassword && (!password.isEmpty || !username.isEmpty) {
                    PasswordManager.shared.save(hostname: challenge.protectionSpace.host, username: username, password: password)
                }
                self?.page?.authenticationViewModel = nil

            }, onCancel: { [weak self] in
                NSApp.mainWindow?.makeFirstResponder(nil)
                completionHandler(.performDefaultHandling, nil)
                self?.page?.authenticationViewModel = nil
            })

            if challenge.previousFailureCount == 0 {
                PasswordManager.shared.credentials(for: challenge.protectionSpace.host) { credentials in
                    if let firstCredential = credentials.first,
                       let decrypted = try? EncryptionManager.shared.decryptString(firstCredential.password, EncryptionManager.shared.localPrivateKey()),
                       !decrypted.isEmpty || !firstCredential.username.isEmpty {
                        completionHandler(.useCredential, URLCredential(user: firstCredential.username, password: decrypted, persistence: .forSession))
                    } else {
                        self.page?.authenticationViewModel = viewModel
                    }
                }
            } else {
                self.page?.authenticationViewModel = viewModel
            }
        case NSURLAuthenticationMethodServerTrust:
            let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, cred)
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // Asks the delegate whether to continue with a connection that uses a deprecated version of TLS.
    public func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(true)
    }

}

// MARK: - Responding to Navigation Errors
extension WebKitNavigationHandler {

    /// Tells the delegate that an error occurred during navigation.
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Webview failed: \(error)", category: .web)
    }

    /// Tells the delegate that an error occurred during the early navigation process.
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("didFail: \(error)", category: .web)
        page?.errorPageManager = nil
        let error = error as NSError

        if error.domain == "WebKitErrorDomain" && error.code == 102 {
            return
        }

        if error.code == Int(CFNetworkErrors.cfurlErrorCancelled.rawValue) {
            return
        }

        guard
            let errorUrl = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL,
            error.code != WebKitErrorFrameLoadInterruptedByPolicyChange else { return }
        let errorManager = ErrorPageManager(error.code, webView: webView, errorUrl: errorUrl, defaultLocalizedDescription: error.localizedDescription)
        self.page?.errorPageManager = errorManager

        if errorManager.error == .radblock {
            webView.load(errorManager.htmlPage(), mimeType: "", characterEncodingName: "utf-8", baseURL: errorUrl)
        } else {
            errorManager.loadPage(for: errorUrl)
        }
    }

    /// Tells the delegate that the web view’s content process was terminated.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { }

}

// MARK: - Handling Download Progress
extension WebKitNavigationHandler {

    ///Tells the delegate that a navigation response became a download.
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        page?.downloadManager?.download(download)
    }

    /// Tells the delegate that a navigation action became a download.
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        page?.downloadManager?.download(download)
    }

}

// MARK: - Helpers
extension WebKitNavigationHandler {

    /// Utility to determine if the Command Key was used during a navigation action
    /// - Parameter action: The Navigation Action
    /// - Returns: true if Command was used
    private func isNavigationWithCommandKey(_ action: WKNavigationAction) -> Bool {
        return action.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)
    }

    /// Handles opening the page in a new tab
    /// - Parameter navigationAction: The NavigationAction to decide if a new tab should be opened
    /// - Returns: True if a new tab is created, false if not
    func openNewTab(_ navigationAction: WKNavigationAction) -> Bool {
        if let page = page, let targetURL = navigationAction.request.url,
           navigationAction.navigationType == .linkActivated,
           isNavigationWithCommandKey(navigationAction) || page.shouldNavigateInANewTab(url: targetURL) {
            _ = page.createNewTab(targetURL, nil, setCurrent: !isNavigationWithCommandKey(navigationAction))
            return true
        } else {
            return false
        }
    }
}
