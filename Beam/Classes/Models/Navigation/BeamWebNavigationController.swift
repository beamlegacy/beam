import Foundation
import BeamCore

class BeamWebNavigationController: WebPageHolder, WebNavigationController {

    let browsingTree: BrowsingTree
    let noteController: WebNoteController

    private var isNavigatingFromSearchBar: Bool = false

    init(browsingTree: BrowsingTree, noteController: WebNoteController) {
        self.browsingTree = browsingTree
        self.noteController = noteController
    }

    func setLoading() {
        isNavigatingFromSearchBar = true
    }

    private var currentBackForwardItem: WKBackForwardListItem?

    private func handleBackForwardWebView(navigationAction: WKNavigationAction) {
        guard let webView = navigationAction.targetFrame?.webView ?? navigationAction.sourceFrame.webView else {
            fatalError("Should emit handleBackForwardWebView() from a webview")
        }
        if navigationAction.navigationType == .backForward {
            let isBack = webView.backForwardList.backList
                .filter { $0 == currentBackForwardItem }
                .count == 0

            if isBack {
                browsingTree.goBack()
            } else {
                browsingTree.goForward()
            }
        }
        page.leave()
        currentBackForwardItem = webView.backForwardList.currentItem
    }

    func navigatedTo(url: URL, webView: WKWebView) {
        let isLinkActivation = !isNavigatingFromSearchBar
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):
                // Note: Readability removes title separators
                self.browsingTree.navigateTo(url: url.absoluteString, title: read.title, startReading: self.page.isActiveTab(),
                                             isLinkActivation: isLinkActivation, readCount: read.content.count)
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

        handleBackForwardWebView(navigationAction: navigationAction)
        if let targetURL = navigationAction.request.url {
            if navigationAction.modifierFlags.contains(.command) {
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
        navigatedTo(url: url, webView: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Webview failed: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }

}
