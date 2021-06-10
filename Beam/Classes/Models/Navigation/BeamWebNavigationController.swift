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
        _ = page.addToNote(allowSearchResult: false)
        let isLinkActivation = !isNavigatingFromSearchBar
        let title = webView.title
        browsingTree.navigateTo(url: url.absoluteString, title: title, startReading: page.isActiveTab(), isLinkActivation: isLinkActivation)
        isNavigatingFromSearchBar = false
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):
                self.browsingTree.current.score.textAmount = read.content.count
                self.page.navigatedTo(url: url, read: read, title: title)
                try? TextSaver.shared?.save(nodeId: self.browsingTree.current.id, text: read)
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
            }
        }
    }
}

extension BeamWebNavigationController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        noteController.clearCurrent()
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        noteController.clearCurrent()
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
        noteController.clearCurrent()

        if let response = navigationResponse.response as? HTTPURLResponse,
           !navigationResponse.canShowMIMEType,
           let url = response.url {
            decisionHandler(.cancel)
            var headers: [String: String] = [:]
            if let sourceURL = webView.url {
                headers["Referer"] = sourceURL.absoluteString
            }
            page.downloadManager.downloadFile(at: url, headers: headers, destinationFoldedURL: nil)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        noteController.clearCurrent()
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        noteController.clearCurrent()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        noteController.clearCurrent()
        Logger.shared.logError("didFail: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        navigatedTo(url: url, webView: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        noteController.clearCurrent()
        Logger.shared.logError("Webview failed: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }
}
