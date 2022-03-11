import AppKit
import Combine
import WebKit
import BeamCore

/// A view displaying an embed object inside a web view.
final class EmbedContentView: NSView {

    weak var delegate: EmbedContentViewDelegate?

    private(set) var webView: BeamWebView?

    private var loadingView: NSView?
    private var webViewProvider: BeamWebViewProviding?
    private var webPage: EmbedNodeWebPage?

    private let borderRadius: CGFloat = 3

    init(frame frameRect: NSRect, webViewProvider: BeamWebViewProviding) {
        self.webViewProvider = webViewProvider

        let loadingView = EmbedLoadingView()
        loadingView.autoresizingMask = [.width, .height]
        self.loadingView = loadingView

        super.init(frame: frameRect)

        layer = CALayer()

        loadingView.frame = bounds
        addSubview(loadingView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        layer?.mask = makeMaskLayer(rect: bounds)
    }

    func startLoadingWebView(embedContent: EmbedContent) {
        webViewProvider?.webView { [weak self] webView, isReusedWebView in
            self?.prepare(webView, isReusedWebView: isReusedWebView, embedContent: embedContent)
        }
    }

    private func prepare(_ webView: BeamWebView, isReusedWebView: Bool, embedContent: EmbedContent) {
        self.webView = webView

        if let embedNodeWebPage = webView.page as? EmbedNodeWebPage {
            webPage = embedNodeWebPage
        } else {
            webPage = EmbedNodeWebPage(webView: webView)
            webView.page = webPage
        }

        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self

        webPage?.delegate = self

        if isReusedWebView {
            showWebView()
        } else {
            Self.inject(embedContent, into: webView)
        }
    }

    private func showWebView() {
        guard let webView = webView, webView.superview == nil else { return }

        loadingView?.removeFromSuperview()
        webView.frame = bounds
        addSubview(webView)
    }

    private func makeMaskLayer(rect: CGRect) -> CAShapeLayer {
        let mask = CAShapeLayer()
        mask.path = makeMaskPath(rect: rect)
        return mask
    }

    private func makeMaskPath(rect: CGRect) -> CGPath {
        let path = NSBezierPath(roundedRect: rect, xRadius: borderRadius, yRadius: borderRadius)
        return path.cgPath
    }

    private static func inject(_ embedContent: EmbedContent, into webView: WKWebView) {
        switch embedContent.type {
        case .page, .audio, .rich, .video, .photo, .image:
            guard let content = embedContent.html else { fallthrough }

            let theme = webView.isDarkMode ? "dark" : "light"
            let resizableClass = embedContent.responsive != nil ? "resize-\(embedContent.responsive!.rawValue)" : "non-resizable"
            let aspectRatioClass = embedContent.keepAspectRatio ? "aspectRatio" : "noAspectRatio"

            let html = """
                <head>
                    <meta name="twitter:dnt" content="on" />
                    <meta name="twitter:widgets:theme" content="\(theme)" />
                    <meta name="twitter:widgets:chrome" content="transparent" />
                </head>

                <div class="iframe \(embedContent.type.rawValue) \(aspectRatioClass) \(resizableClass)">
                    \(content)
                </div>
            """

            webView.loadHTMLString(html, baseURL: URL(string: "https://example.com"))

        default:
            if let url = embedContent.embedURL {
                webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
            }
        }
    }

}

// MARK: - EmbedNodeWebPageDelegate

extension EmbedContentView: EmbedNodeWebPageDelegate {

    func embedNodeDidUpdateMediaController(_ controller: MediaPlayerController?) {
        delegate?.embedContentView(self, didUpdateMediaPlayerController: controller)
    }

    func embedNodeDelegateCallback(size: CGSize) {
        delegate?.embedContentView(self, contentSizeDidChange: size)
    }

}

// MARK: - WKNavigationDelegate

extension EmbedContentView: WKNavigationDelegate {

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .embed)
        decisionHandler(.allow)
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        // When clicking on a link inside the EmbedNode
        guard
            let targetURL = navigationAction.request.url,
            navigationAction.navigationType == .linkActivated
        else {
            Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction)), allow navigation", category: .embed)

            decisionHandler(.allow, preferences)
            return
        }

        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction)), cancel navigation, creating new tab", category: .embed)

        delegate?.embedContentView(self, didRequestNewTab: targetURL)

        // Don't navigate the EmbedNode
        decisionHandler(.cancel, preferences)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationResponse))", category: .embed)
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didStartProvisionalNavigation: \(String(describing: navigation))", category: .embed)
    }

    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didReceiveServerRedirectForProvisionalNavigation: \(String(describing: navigation))", category: .embed)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logDebug("Embed didFailProvisionalNavigation: \(String(describing: navigation))", category: .embed)
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didCommit: \(String(describing: navigation))", category: .embed)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didFinish: \(String(describing: navigation))", category: .embed)

        showWebView()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Embed Error: \(error)", category: .embed)
    }

    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    public func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(true)
    }

}
