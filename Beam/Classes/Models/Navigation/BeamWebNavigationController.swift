import Foundation
import BeamCore
import WebKit

class BeamWebNavigationController: BaseWebNavigationController, WebPageRelated, WebNavigationController {
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

    /// Tells the delegate that navigation is complete.
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
        guard let url = webView.url else { return }
        navigatedTo(url: url, webView: webView, replace: false)
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

    // swiftlint:disable:next cyclomatic_complexity
    func navigatedTo(url: URL, webView: WKWebView, replace: Bool, fromJS: Bool = false) {
        guard let page = self.page else {
            return
        }
        // If the webview is loading, we should not index the content.
        // We will be called by the webView delegate at the end of the loading
        guard !webView.isLoading else {
            return
        }

        // Only register navigation if the page was successfully loaded
        guard page.responseStatusCode == 200 else { return }

        // handle the case where a redirection happened and we never get a title for the original url:
        if let requestedUrl = page.requestedURL, requestedUrl != url {
            Logger.shared.logInfo("Mark original request of navigation as visited with resulting title \(requestedUrl) - \(String(describing: webView.title))")
            let urlToIndex = requestedUrl.absoluteString
            let destinationUrl = requestedUrl.isDomain ? url.domain ?? url : url //helps in notion case, when domain alias redirects to a sub page and we want domain alias frecency to be the same as domain frecency
            let link = LinkStore.shared.visit(urlToIndex, title: webView.title, content: nil, destination: destinationUrl.absoluteString)
            ExponentialFrecencyScorer(storage: LinkStoreFrecencyUrlStorage()).update(id: link.id, value: 1.0, eventType: .webDomainIncrement, date: BeamDate.now, paramKey: .webVisit30d0)
        }

        let isLinkActivation = !isNavigatingFromSearchBar && !replace
        isNavigatingFromSearchBar = false

        page.navigatedTo(url: url, title: webView.title, reason: isLinkActivation ? .navigation : .loading)

        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):

                //This is ugly, and should be refactored using new async syntax when possible
                // But it's needed to try to index the good content when navigating from JS
                if fromJS {
                    let reIndexDelay = 4
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(reIndexDelay)) {
                        Readability.read(webView) { [weak self] result2 in
                            switch result2 {
                            case let .success(read2):
                                if read2 != read, let webViewURL = self?.webView?.url, webViewURL == url {
                                    self?.indexVisit(url: url, isLinkActivation: isLinkActivation, read: read2)
                                } else {
                                    self?.indexVisit(url: url, isLinkActivation: isLinkActivation, read: read)
                                }
                            case let .failure(error):
                                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
                                self?.indexVisit(url: url, isLinkActivation: isLinkActivation)
                            }
                        }
                    }
                } else {
                    self.indexVisit(url: url, isLinkActivation: isLinkActivation, read: read)
                }
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
                self.browsingTree.navigateTo(url: url.absoluteString, title: webView.title, startReading: page.isActiveTab(), isLinkActivation: isLinkActivation, readCount: 0)
            }
        }
    }

    private func indexVisit(url: URL, isLinkActivation: Bool, read: Readability? = nil) {
        guard let page = self.page else { return }
        //Alway index the visit, event if we were not able to read the content
        let title = read?.title ?? webView?.title
        self.browsingTree.navigateTo(url: url.absoluteString, title: title, startReading: page.isActiveTab(), isLinkActivation: isLinkActivation, readCount: read?.content.count ?? 0)

        guard let read = read else { return }
        try? TextSaver.shared?.save(nodeId: self.browsingTree.current.id, text: read)
        page.appendToIndexer?(url, title ?? "", read)
    }

    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                          preferences: WKWebpagePreferences,
                          decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {

        super.webView(webView, decidePolicyFor: navigationAction, preferences: preferences, decisionHandler: decisionHandler)

        switch navigationAction.navigationType {
        case .backForward:
            handleBackForwardWebView(navigationAction: navigationAction)
        default:
            Logger.shared.logInfo("Nav Redirecting toward: \(navigationAction.request.url?.absoluteString ?? "nilURL"), type:\(navigationAction.navigationType)",
                                  category: .web)
        }

    }
}
