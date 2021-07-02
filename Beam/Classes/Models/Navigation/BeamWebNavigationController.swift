import Foundation
import BeamCore

class BeamWebNavigationController: WebPageHolder, WebNavigationController {

    let browsingTree: BrowsingTree
    let noteController: WebNoteController

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
        let isLinkActivation = !isNavigatingFromSearchBar
        let earlyTitle = webView.title
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):
                // Note: Readability removes title separators
                self.browsingTree.navigateTo(url: url.absoluteString, title: read.title, startReading: self.page.isActiveTab(),
                                             isLinkActivation: isLinkActivation, readCount: read.content.count)
                let webPageTitle = self.page.title
                self.page.navigatedTo(url: url, read: read, title: read.title, isNavigation: isLinkActivation)
                try? TextSaver.shared?.save(nodeId: self.browsingTree.current.id, text: read)
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
            }
        }
        isNavigatingFromSearchBar = false
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
        case .other:
            Logger.shared.logInfo("Nav Redirecting toward \(String(describing: navigationAction.request.url?.absoluteString))")
        default:
            Logger.shared.logInfo("Creating new webview for \(String(describing: navigationAction.request.url?.absoluteString))", category: .web)
        }
        if let targetURL = navigationAction.request.url {
            if navigationAction.modifierFlags.contains(.command) {
                Logger.shared.logInfo("Cmd required create new tab toward \(String(describing: navigationAction.request.url))")
                _ = page.createNewTab(targetURL, nil, setCurrent: false)
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
            page.downloadManager.downloadFile(at: url, headers: headers, suggestedFileName: response.suggestedFilename, destinationFoldedURL: nil)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("didFail: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

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
            // TODO: Add UI to ask User for login and password (BE-1280)
            let userId = "user"
            let password = "pass"
            let credential = URLCredential(user: userId, password: password, persistence: .none)
            completionHandler(.useCredential, credential)
        } else if authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, cred)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }

    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }

}
