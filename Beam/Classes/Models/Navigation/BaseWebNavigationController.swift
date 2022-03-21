//
//  BaseWebNavigationController.swift
//  Beam
//
//  Created by Stef Kors on 24/02/2022.
//

import Foundation
import BeamCore
import WebKit

class BaseWebNavigationController: NSObject, WKNavigationDelegate {
    /// The target WebPage. Used as a target for where new Tabs will be created
    weak var page: WebPage?
}

// MARK: - Allowing or Denying Navigation Requests
extension BaseWebNavigationController {

    /// Asks the delegate for permission to navigate to new content based on the specified action information.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        handleNavigationAction(navigationAction)
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

        self.handleNavigationAction(navigationAction)

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
        if let page = page, let targetURL = navigationAction.request.url,
           navigationAction.navigationType == .linkActivated,
           isNavigationWithCommandKey(navigationAction) || page.shouldNavigateInANewTab(url: targetURL) {
            _ = page.createNewTab(targetURL, nil, setCurrent: !isNavigationWithCommandKey(navigationAction))
            decisionHandler(.cancel, preferences)
            return
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
extension BaseWebNavigationController {

    /// Tells the delegate that navigation from the main frame has started.
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

    /// Tells the delegate that the web view received a server redirect for a request.
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) { }

    /// Tells the delegate that the web view has started to receive content for the main frame.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let webviewUrl = webView.url else {
            return // webview probably failed to load
        }

        page?.contentDescription = NavigationRouter.browserContentDescription(for: webviewUrl, webView: webView)

        if BeamURL(webviewUrl).isErrorPage {
            let beamSchemeUrl = BeamURL(webviewUrl)
            self.page?.url = beamSchemeUrl.originalURLFromErrorPage

            if let extractedCode = BeamURL.getQueryStringParameter(url: beamSchemeUrl.url.absoluteString, param: "code"),
               let errorCode = Int(extractedCode),
               let errorUrl = self.page?.url {
                self.page?.errorPageManager = .init(errorCode, webView: webView,
                                                    errorUrl: errorUrl,
                                                    defaultLocalizedDescription: BeamURL.getQueryStringParameter(url: beamSchemeUrl.url.absoluteString, param: "localizedDescription"))
            }

        } else {
            // Present the original, non-internal URL
            page?.url = NavigationRouter.originalURL(internal: webviewUrl)
        }
        self.page?.leave()
        (page as? BrowserTab)?.updateFavIcon(fromWebView: false, cacheOnly: true, clearIfNotFound: true)
    }

    /// Tells the delegate that navigation is complete.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { }

}

// MARK: - Responding to Authentication Challenges
extension BaseWebNavigationController {

    /// Asks the delegate to respond to an authentication challenge.
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        if authenticationMethod == NSURLAuthenticationMethodDefault || authenticationMethod == NSURLAuthenticationMethodHTTPBasic || authenticationMethod == NSURLAuthenticationMethodHTTPDigest {

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
        } else if authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, cred)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // Asks the delegate whether to continue with a connection that uses a deprecated version of TLS.
    public func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(true)
    }

}

// MARK: - Responding to Navigation Errors
extension BaseWebNavigationController {

    /// Tells the delegate that an error occurred during navigation.
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Webview failed: \(error)", category: .javascript)
    }

    /// Tells the delegate that an error occurred during the early navigation process.
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("didFail: \(error)", category: .javascript)
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
extension BaseWebNavigationController {

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
extension BaseWebNavigationController {

    private func handleNavigationAction(_ action: WKNavigationAction) {
        switch action.navigationType {
        case .other:
            // this is a redirect, we keep the requested url as is to update its title once the actual destination is reached
            break
        case .formSubmitted, .formResubmitted:
            // We found at that `action.sourceFrame` can be null for `.formResubmitted` even if it's not an optional
            // Assigning it to an optional to check if we have a value
            // see https://linear.app/beamapp/issue/BE-3180/exc-breakpoint-exception-6-code-3431810664-subcode-8
            let sourceFrame: WKFrameInfo? = action.sourceFrame
            if let sourceFrame = sourceFrame {
                Logger.shared.logDebug("Form submitted for \(sourceFrame.request.url?.absoluteString ?? "(no source frame URL)")", category: .web)
                page?.handleFormSubmit(frameInfo: sourceFrame)
            }
            fallthrough
        default:
            // update the requested url as it is not from a redirection but from a user action:
            if let url = action.request.url {
                self.page?.requestedURL = url
            }
        }
    }

    /// Utility to determine if the Command Key was used during a navigation action
    /// - Parameter action: The Navigation Action
    /// - Returns: true if Command was used
    private func isNavigationWithCommandKey(_ action: WKNavigationAction) -> Bool {
        return action.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)
    }

}
