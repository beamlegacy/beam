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

    private let sizeRatio = 240.0/320.0

    private var embedUrl: URL? {
        guard case .embed(let sourceURL, _) = element.kind else { return nil }
        return URL(string: sourceURL)?.embed
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
            Logger.shared.logError("EmbedNode can only handle url elements, not \(element.kind)", category: .noteEditor)
            return
        }

        if case .embed(_, let ratio) = element.kind {
            desiredWidthRatio = ratio
        }

        guard let url = embedUrl else { return }

        setupResizeHandleLayer()

        let webviewConfiguration = EmbedNode.webViewConfiguration
        var webView: BeamWebView?
        if let note = editor?.note as? BeamNote {
            webView = mediaPlayerManager?.playingWebViewForNote(note: note, elementId: elementId, url: url)
            webPage = webView?.page as? EmbedNodeWebPage
        }

        if webView == nil {
            let wv = BeamWebView(frame: .zero, configuration: webviewConfiguration)
            wv.setupForEmbed()
            let p = EmbedNodeWebPage(webView: wv)
            webPage = p
            wv.page = p
            AppDelegate.main.data.setup(webView: wv)
            wv.load(URLRequest(url: url))
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

    private func clearWebViewAndStopPlaying() {
        guard let note = editor?.note as? BeamNote,
              let url = self.embedUrl else { return }
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
        let visibleSize = visibleSize

        webView?.frame = NSRect(x: r.minX, y: r.minY, width: visibleSize.width, height: visibleSize.height)
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
              let url = self.embedUrl else { return }
        if controller?.isPlaying == true {
            mediaManager.addNotePlaying(note: note, elementId: elementId, webView: webView)
        } else {
            mediaManager.stopNotePlaying(note: note, elementId: elementId, url: url)
        }
    }
}

extension EmbedNode: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .noteEditor)
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .noteEditor)
        decisionHandler(.allow, preferences)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationResponse))", category: .noteEditor)
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didStartProvisionalNavigation: \(String(describing: navigation))", category: .noteEditor)
    }

    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didReceiveServerRedirectForProvisionalNavigation: \(String(describing: navigation))", category: .noteEditor)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logDebug("Embed didFailProvisionalNavigation: \(String(describing: navigation))", category: .noteEditor)
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didCommit: \(String(describing: navigation))", category: .noteEditor)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didFinish: \(String(describing: navigation))", category: .noteEditor)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Embed Error: \(error)", category: .noteEditor)
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
