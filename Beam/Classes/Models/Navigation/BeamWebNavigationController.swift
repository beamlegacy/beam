import Foundation
import BeamCore

class BeamWebNavigationController: WebPageHolder, WebNavigationController {

    let browsingTree: BrowsingTree
    let noteController: WebNoteController

    public var isNavigatingFromNote: Bool = false
    private var isNavigatingFromSearchBar: Bool = false
    private weak var webView: WKWebView?

    init(browsingTree: BrowsingTree, noteController: WebNoteController, webView: WKWebView) {
        self.browsingTree = browsingTree
        self.noteController = noteController
        self.webView = webView
    }

    func setLoading() {
        isNavigatingFromSearchBar = true
    }

    private var currentBackForwardItem: WKBackForwardListItem?

    private func handleBackForwardWebView(navigationAction: WKNavigationAction) {
        guard let webView = navigationAction.targetFrame?.webView ?? navigationAction.sourceFrame.webView else {
            fatalError("Should emit handleBackForwardWebView() from a webview")
        }
        let isBack = webView.backForwardList.backList
            .filter { $0 == currentBackForwardItem }
            .count == 0

        if isBack {
            browsingTree.goBack()
        } else {
            browsingTree.goForward()
        }
        currentBackForwardItem = webView.backForwardList.currentItem
    }

    func navigatedTo(url: URL, webView: WKWebView, replace: Bool) {
        let isLinkActivation = !isNavigatingFromSearchBar && !replace
        isNavigatingFromSearchBar = false
        self.page.navigatedTo(url: url, title: webView.title, reason: isLinkActivation ? .navigation : .loading)
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):
                guard self.page.responseStatusCode == 200 else { return }
                self.browsingTree.navigateTo(url: url.absoluteString, title: read.title, startReading: self.page.isActiveTab(),
                                             isLinkActivation: isLinkActivation, readCount: read.content.count)
                self.page.appendToIndexer?(url, read)
                try? TextSaver.shared?.save(nodeId: self.browsingTree.current.id, text: read)
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
            }
        }
    }

    private func shouldDownloadFile(for navigationResponse: WKNavigationResponse) -> Bool {

        guard let response = navigationResponse.response as? HTTPURLResponse else { return false }

        let contentDisposition = BeamDownloadManager.contentDisposition(from: response.allHeaderFields)

        if let disposition = contentDisposition {
            return disposition == .attachment
        } else if !navigationResponse.canShowMIMEType {
            return true
        } else {
            return false
        }
    }
}

extension BeamWebNavigationController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        switch navigationAction.navigationType {
        case .backForward:
            handleBackForwardWebView(navigationAction: navigationAction)
        default:
            Logger.shared.logInfo("Nav Redirecting toward: \(navigationAction.request.url?.absoluteString ?? "nilURL"), type:\(navigationAction.navigationType)",
                                  category: .web)
        }

        if let targetURL = navigationAction.request.url {
            let navigationUrlHandler = ExternalDeeplinkHandler(request: navigationAction.request)
            let withCommandKey = navigationAction.modifierFlags.contains(.command)
            if navigationUrlHandler.isDeeplink() {
                decisionHandler(.cancel, preferences)
                if navigationUrlHandler.shouldOpenDeeplink() {
                    NSWorkspace.shared.open(targetURL)
                }
                return
            } else if navigationAction.navigationType == .linkActivated && (withCommandKey || page.shouldNavigateInANewTab(url: targetURL)) {
                if withCommandKey {
                    Logger.shared.logInfo("Cmd required create new tab toward: \(String(describing: targetURL))", category: .web)
                } else {
                    Logger.shared.logInfo("WebPage required to create a new tab for \(String(describing: targetURL))", category: .web)
                }
                _ = page.createNewTab(targetURL, nil, setCurrent: !withCommandKey)
                decisionHandler(.cancel, preferences)
                return
            }

        }
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        if let response = navigationResponse.response as? HTTPURLResponse,
           let url = response.url,
           shouldDownloadFile(for: navigationResponse) {
            decisionHandler(.cancel)
            var headers: [String: String] = [:]
            if let sourceURL = webView.url {
                headers["Referer"] = sourceURL.absoluteString
            }
            page.downloadManager?.downloadFile(at: url, headers: headers, suggestedFileName: response.suggestedFilename, destinationFoldedURL: DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder)?.sandboxAccessibleUrl)
        } else {
            if let response = navigationResponse.response as? HTTPURLResponse {
                page.responseStatusCode = response.statusCode
            }
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) { }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("didFail: \(error)", category: .javascript)
        page.errorPageManager = nil
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
        page.errorPageManager = errorManager

        if errorManager.error == .radblock {
            webView.load(errorManager.htmlPage(), mimeType: "", characterEncodingName: "utf-8", baseURL: errorUrl)
        } else {
            errorManager.loadPage(for: errorUrl)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        navigatedTo(url: url, webView: webView, replace: false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Webview failed: \(error)", category: .javascript)
    }

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
                self?.page.authenticationViewModel = nil

            }, onCancel: { [weak self] in
                NSApp.mainWindow?.makeFirstResponder(nil)
                completionHandler(.performDefaultHandling, nil)
                self?.page.authenticationViewModel = nil
            })

            if challenge.previousFailureCount == 0 {
                PasswordManager.shared.credentials(for: challenge.protectionSpace.host) { credentials in
                    if let firstCredential = credentials.first,
                       let decrypted = try? EncryptionManager.shared.decryptString(firstCredential.password),
                       !decrypted.isEmpty || !firstCredential.username.isEmpty {
                        completionHandler(.useCredential, URLCredential(user: firstCredential.username, password: decrypted, persistence: .forSession))
                    } else {
                        self.page.authenticationViewModel = viewModel
                    }
                }
            } else {
                self.page.authenticationViewModel = viewModel
            }
        } else if authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, cred)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { }

}
