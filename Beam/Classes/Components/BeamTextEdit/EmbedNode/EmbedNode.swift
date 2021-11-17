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

private class EmbedNodeWebViewConfiguration: BeamWebViewConfigurationBase {
    override func registerAllMessageHandlers() {
        LoggingMessageHandler(config: self).register(to: self)
        MediaPlayerMessageHandler(config: self).register(to: self)
    }
}

class EmbedNode: ResizableNode {

    private static var webViewConfiguration = EmbedNodeWebViewConfiguration()
    var webView: BeamWebView?
    private var webPage: EmbedNodeWebPage?
    private var embedCancellables = Set<AnyCancellable>()
    private let sizeRatio = 240.0/320.0
    private var loadingView: NSView?
    private var isLoadingEmbed = false {
        didSet {
            loadingView?.isHidden = !isLoadingEmbed
        }
    }

    private var sourceURL: URL? {
        guard case .embed(let sourceURL, _) = element.kind, let url = URL(string: sourceURL) else { return nil }
        return url
    }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        super.init(parent: parent, element: element, availableWidth: availableWidth)

        setupEmbed(availableWidth: availableWidth ?? fallBackWidth)
    }

    init(editor: BeamTextEdit, element: BeamElement, availableWidth: CGFloat?) {
        super.init(editor: editor, element: element, availableWidth: availableWidth)

        setupEmbed(availableWidth: availableWidth ?? fallBackWidth)
    }

    func setupEmbed(availableWidth: CGFloat) {
        guard case .embed = element.kind else {
            Logger.shared.logError("EmbedNode can only handle url elements, not \(element.kind)", category: .embed)
            return
        }

        if case .embed(_, let ratio) = element.kind {
            desiredWidthRatio = ratio
        }

        setupResizeHandleLayer()

        guard let sourceURL = sourceURL else { return }

        let webviewConfiguration = EmbedNode.webViewConfiguration
        var webView: BeamWebView?
        if let note = editor?.note as? BeamNote {
            webView = mediaPlayerManager?.playingWebViewForNote(note: note, elementId: elementId, url: sourceURL)
            webPage = webView?.page as? EmbedNodeWebPage
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

        webView?.navigationDelegate = self
        webView?.wantsLayer = true
        webView?.allowsMagnification = true
        webPage?.delegate = self
        if let webView = webView {
            editor?.addSubview(webView)
        }

        self.webView = webView

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)

        contentsPadding = NSEdgeInsets(top: 4, left: contentsPadding.left + 4, bottom: 14, right: 4)

        // Embed don't have size on there own… By default, they are as wide as the editor
        let height = availableWidth  * CGFloat(sizeRatio)
        resizableElementContentSize = CGSize(width: availableWidth, height: height)

        setupLoader()
        updateEmbedContent()
    }

    deinit {
        let nodeStillOwnsTheWebView = webPage?.delegate as? EmbedNode == self
        if nodeStillOwnsTheWebView || webPage?.delegate == nil {
            webView?.removeFromSuperview()
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

    private func updateEmbedContent() {
        guard let sourceURL = sourceURL else { return }

        embedCancellables.removeAll()
        let builder = EmbedContentBuilder()
        if let embedUrl = builder.embeddableContent(for: sourceURL)?.embedURL {
            webView?.load(URLRequest(url: embedUrl))
        } else {
            isLoadingEmbed = true
            builder.embeddableContentAsync(for: sourceURL)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    switch completion {
                    case .failure(_):
                        Logger.shared.logError("Embed Node couldn't load content for \(sourceURL.absoluteString)", category: .embed)
                    case .finished:
                        break
                    }
                    self?.isLoadingEmbed = false
                    self?.embedCancellables.removeAll()
                } receiveValue: { [weak self] embedContent in
                    if [.url, .image].contains(embedContent.type), let url = embedContent.embedURL {
                        self?.webView?.load(URLRequest(url: url))
                    } else if embedContent.type == .page, let content = embedContent.embedContent {
                        self?.webView?.loadHTMLString(content, baseURL: nil)
                    }
                }.store(in: &embedCancellables)
        }
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

        let height = availableWidth  * CGFloat(sizeRatio)
        resizableElementContentSize = CGSize(width: availableWidth, height: height)

        let r = layer.frame
        webView?.frame = CGRect(x: r.minX, y: r.minY, width: visibleSize.width, height: visibleSize.height)
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
        AppDelegate.main.window?.state.noteMediaPlayerManager
    }

    func embedNodeDidUpdateMediaController(_ controller: MediaPlayerController?) {
        guard let note = root?.editor?.note as? BeamNote,
              let webView = webView,
              let mediaManager = mediaPlayerManager,
              let url = self.sourceURL else { return }
        if controller?.isPlaying == true {
            mediaManager.addNotePlaying(note: note, elementId: elementId, webView: webView)
        } else {
            mediaManager.stopNotePlaying(note: note, elementId: elementId, url: url)
        }
    }
}

extension EmbedNode: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .embed)
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .embed)
        decisionHandler(.allow, preferences)
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
