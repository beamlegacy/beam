//
//  EmbedNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/05/2021.
//

import Foundation
import BeamCore
import AppKit
import WebKit
import Combine

class EmbedNode: ResizableNode {

    private static var webViewConfiguration = EmbedNodeWebViewConfiguration()
    var webView: BeamWebView?
    private var embedContent: EmbedContent?
    private var embedView = NSView()
    private var webPage: EmbedNodeWebPage?
    private var embedCancellables = Set<AnyCancellable>()
    private let defaultSizeRatio = 240.0/320.0
    private var loadingView: NSView?
    private var isLoadingEmbed = false {
        didSet {
            loadingView?.isHidden = !isLoadingEmbed
        }
    }

    private var sourceURL: URL? {
        guard case .embed(let url, _, _) = element.kind else { return nil }
        return url
    }

    override func setBottomPaddings(withDefault: CGFloat) {
        super.setBottomPaddings(withDefault: 14)
    }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat) {
        super.init(parent: parent, element: element, availableWidth: availableWidth)

        setupEmbed(availableWidth: availableWidth)
    }

    init(editor: BeamTextEdit, element: BeamElement, availableWidth: CGFloat) {
        super.init(editor: editor, element: element, availableWidth: availableWidth)

        setupEmbed(availableWidth: availableWidth)
    }

    func setupEmbed(availableWidth: CGFloat) {
        guard case .embed = element.kind else {
            Logger.shared.logError("EmbedNode can only handle url elements, not \(element.kind)", category: .embed)
            return
        }

        setupResizeHandleLayer()

        guard let sourceURL = sourceURL else { return }

        let webviewConfiguration = EmbedNode.webViewConfiguration
        var webView: BeamWebView?
        var isReusedWebview = false
        if let note = editor?.note as? BeamNote {
            webView = mediaPlayerManager?.playingWebViewForNote(note: note, elementId: elementId, url: sourceURL)
            webPage = webView?.page as? EmbedNodeWebPage
            isReusedWebview = webView != nil
        }

        if webView == nil {
            let wv = BeamWebView(frame: .zero, configuration: webviewConfiguration)
            wv.setupForEmbed()
            let p = EmbedNodeWebPage(webView: wv)
            webPage = p
            wv.page = p
            AppDelegate.main.data.setup(webView: wv)
            webView = wv
        }

        webPage?.delegate = self
        if let webView = webView {
            webView.navigationDelegate = self
            webView.wantsLayer = true
            webView.allowsMagnification = true
            let webFrame = CGRect(x: 0, y: 0, width: 150, height: 150)
            embedView.frame = webFrame
            webView.frame = CGRect(origin: .zero, size: webFrame.size)
            webView.autoresizingMask = [.width, .height]
            embedView.alphaValue = 0
            embedView.addSubview(webView)
            editor?.addSubview(embedView)
        }

        self.webView = webView

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)

        contentsPadding = NSEdgeInsets(top: 4, left: contentsPadding.left + 4, bottom: 14, right: 4)

        updateResizableElementContentSize(with: embedContent)
        setupLoader()
        updateEmbedContent(updateWebview: !isReusedWebview)
    }

    deinit {
        let nodeStillOwnsTheWebView = webPage?.delegate as? EmbedNode == self
        if nodeStillOwnsTheWebView || webPage?.delegate == nil {
            webView?.removeFromSuperview()
            embedView.removeFromSuperview()
        }
    }

    override func willBeRemovedFromNote() {
        super.willBeRemovedFromNote()
        clearWebViewAndStopPlaying()
    }

    private func setupLoader() {
        let text = NSTextField(labelWithAttributedString: NSAttributedString(string: "Loading...", attributes: [
            .font: BeamFont.regular(size: 13).nsFont,
            .foregroundColor: BeamColor.AlphaGray.nsColor
        ]))
        let container = NSView()
        container.isHidden = true
        container.wantsLayer = true
        container.layer?.backgroundColor = BeamColor.Nero.cgColor
        container.addSubview(text)
        container.frame = webView?.bounds ?? .zero
        container.autoresizingMask = [.width, .height]
        text.translatesAutoresizingMaskIntoConstraints = false
        container.addConstraints([
            text.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            text.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        webView?.addSubview(container)
        self.loadingView = container
    }

    /// Display EmbedContent in WebView
    /// - Parameter embedContent: EmbedContent to display
    fileprivate func loadEmbedContentInWebView(_ embedContent: EmbedContent) {
        updateResizableElementContentSize(with: embedContent)
        self.updateLayout()
        switch embedContent.type {
        case .url, .link:
            if let url = embedContent.embedURL {
                self.webView?.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
            }
        case .page, .audio, .rich, .video, .photo, .image:
            if let content = embedContent.html {
                let theme = self.webView?.isDarkMode ?? false ? "dark" : "light"
                let headContent = self.getHeadContent(theme: theme)
                self.webView?.loadHTMLString(headContent + content, baseURL: nil)
            }
        }
    }

    private func updateEmbedContent(updateWebview: Bool) {
        guard let sourceURL = sourceURL else { return }

        embedCancellables.removeAll()
        let builder = EmbedContentBuilder()
        if let embedContent = builder.embeddableContent(for: sourceURL) {
            self.embedContent = embedContent
            if updateWebview {
                self.loadEmbedContentInWebView(embedContent)
            }
        } else {
            isLoadingEmbed = true
            builder.embeddableContentAsync(for: sourceURL)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    switch completion {
                    case .failure:
                        Logger.shared.logError("Embed Node couldn't load content for \(sourceURL.absoluteString)", category: .embed)
                    case .finished:
                        break
                    }
                    self?.isLoadingEmbed = false
                    self?.embedCancellables.removeAll()
                } receiveValue: { [weak self] embedContent in
                    self?.embedContent = embedContent
                    if updateWebview {
                        self?.loadEmbedContentInWebView(embedContent)
                    }
                }.store(in: &embedCancellables)
        }
    }

    /// Returns html a `<head>` tag to correctly style the twitter embed and the webview background
    /// in both Light and Dark color schemes.Css and Scripts are added via EmbedNode.ts
    /// - Parameter theme: The inital "dark" or "light" theme
    /// - Returns: html `<head>`tag as String
    private
    // swiftlint:disable:next function_body_length
    func getHeadContent(theme: String) -> String {
        return """
            <head>
                <meta name="twitter:dnt" content="on" />
                <meta name="twitter:widgets:theme" content="\(theme)" />
                <meta name="twitter:widgets:chrome" content="transparent" />
            </head>
        """
    }

    private func clearWebViewAndStopPlaying() {
        guard let note = editor?.note as? BeamNote,
              let url = self.sourceURL else { return }
        mediaPlayerManager?.stopNotePlaying(note: note, elementId: elementId, url: url)
        webView?.page = nil
        webPage = nil
    }

    override func updateRendering() -> CGFloat {
        updateFocus()
        return visibleSize.height
    }

    override func updateLayersVisibility() {
        super.updateLayersVisibility()
        webView?.isHidden = layer.isHidden
    }

    override func updateLayout() {
        super.updateLayout()
        let r = layer.frame
        let embedFrame = CGRect(x: r.minX, y: r.minY, width: visibleSize.width, height: visibleSize.height)
        DispatchQueue.main.async { [weak self] in
            self?.embedView.frame = embedFrame
            self?.embedView.alphaValue = r == .zero ? 0 : 1
        }
    }

    /// Updates the resizableElementContentSize with the EmbedContent width and height
    /// - Parameter content: EmbedContent of this EmbedNode
    func updateResizableElementContentSize(with content: EmbedContent?) {
        if let content = content {
            if let width = content.width {
                resizableElementContentSize.width = width
            }

            if let height = content.height {
                resizableElementContentSize.height = height
            }

            if let width = content.width, let height = content.height {
                desiredHeightRatio = (1 / width) * height
            }
        } else {
            let height = availableWidth  * CGFloat(defaultSizeRatio)
            resizableElementContentSize = CGSize(width: availableWidth, height: height)
        }
    }

    var focusMargin = CGFloat(3)
    public override func updateElementCursor() {
        let bounds = webView?.bounds ?? .zero
        let cursorRect = NSRect(x: caretIndex == 0 ? -4 : (bounds.width + 2), y: -focusMargin, width: 2, height: bounds.height + focusMargin * 2)
        layoutCursor(cursorRect)
    }

    var focusLayer: CALayer?
    override func updateFocus() {
        focusLayer?.removeFromSuperlayer()

        guard isFocused else {
            return
        }

        let bounds = (webView?.bounds ?? .zero).insetBy(dx: -focusMargin, dy: -focusMargin)
        let position = CGPoint(x: 0, y: 0)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2)

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        mask.position = position

        let borderPath = NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2)
        let borderLayer = CAShapeLayer()
        borderLayer.path = borderPath.cgPath
        borderLayer.lineWidth = 5
        borderLayer.strokeColor = selectionColor.cgColor
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.bounds = bounds
        borderLayer.position = CGPoint(x: contentsLead - 3 + bounds.width / 2, y: 1 + bounds.height / 2)
        borderLayer.mask = mask
        layer.addSublayer(borderLayer)
        focusLayer = borderLayer
    }

    override func onUnfocus() {
        updateFocus()
    }

    override func onFocus() {
        updateFocus()
    }
}

extension EmbedNode: EmbedNodeWebPageDelegate {
    var mediaPlayerManager: NoteMediaPlayerManager? {
        self.editor?.state?.noteMediaPlayerManager
    }

    func embedNodeDidUpdateMediaController(_ controller: MediaPlayerController?) {
        guard let note = root?.editor?.note as? BeamNote,
              let webView = webView,
              let mediaManager = mediaPlayerManager,
              let url = self.sourceURL else { return }
        if controller?.isPlaying == true {
            mediaManager.addNotePlaying(note: note, elementId: elementId, webView: webView, url: url)
        } else {
            mediaManager.stopNotePlaying(note: note, elementId: elementId, url: url)
        }
    }

    /// Gets called from the EmbedNodeMessageHandler with updated sizes when resizing the webview
    /// - Parameter size: Computed width and height from JS
    func embedNodeDelegateCallback(size: CGSize) {
        if embedContent?.height == nil {
            resizableElementContentSize.height = size.height
            self.invalidateLayout()
        } else if let content = embedContent, content.width != nil, content.height != nil {
            // with both height and width defined scale by ratio
            let newRatio = (1 / size.width) * size.height
            desiredHeightRatio = newRatio
            self.invalidateLayout()
        }
    }
}

extension EmbedNode: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .embed)
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        // When clicking on a link inside the EmbedNode
        guard let targetURL = navigationAction.request.url,
              navigationAction.navigationType == .linkActivated,
              let destinationNote = root?.editor?.note as? BeamNote,
              let rootElement = root?.element,
              let state = self.editor?.state else {
            Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction)), allow navigation", category: .embed)
            decisionHandler(.allow, preferences)
            return
        }

        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction)), cancel navigation, creating new tab", category: .embed)
        // Create a new tab with the targetURL, the current note as destinationNote and the embedNode as rootElement
        _ = state.createTab(withURL: targetURL, note: destinationNote, rootElement: rootElement)

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
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Embed Error: \(error)", category: .embed)
    }

    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {

    }

    public func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(true)
    }

}

// MARK: - EmbedNode + Layer
extension EmbedNode {
    override var bulletLayerPositionY: CGFloat { 9 }
}
