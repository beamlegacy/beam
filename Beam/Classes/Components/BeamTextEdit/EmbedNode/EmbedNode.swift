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

public class EmbedNode: ElementNode {

    private static var webViewConfiguration = EmbedNodeWebViewConfiguration()
    var webView: BeamWebView?
    private var webPage: EmbedNodeWebPage?

    private var embedUrl: URL? {
        guard case .embed(let sourceURL) = element.kind else { return nil }
        return URL(string: sourceURL)?.embed
    }

    init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element)

        setupEmbed()

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element)

        setupEmbed()

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)
    }

    func setupEmbed() {
        guard case .embed = element.kind else {
            Logger.shared.logError("EmbedNode can only handle url elements, not \(element.kind)", category: .noteEditor)
            return
        }

        guard let url = embedUrl else { return }

        let webviewConfiguration = EmbedNode.webViewConfiguration
        var webView: BeamWebView?
        if let note = editor.note as? BeamNote {
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
            editor.addSubview(webView)
        }

        self.webView = webView
        let embedLayer = Layer.init(name: "embed", layer: CALayer())
        embedLayer.layer.position = CGPoint(x: indent, y: 0)
        addLayer(embedLayer, origin: CGPoint(x: indent, y: 0))
        layer.zPosition = -1
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
        guard let note = editor.note as? BeamNote,
              let url = self.embedUrl else { return }
        mediaPlayerManager?.stopNotePlaying(note: note, elementId: elementId, url: url)
        webView?.page = nil
        webPage = nil
    }

    let embedWidth = CGFloat(320)
    let embedHeight = CGFloat(240)
    override var elementNodePadding: NSEdgeInsets {
        NSEdgeInsets(top: 4, left: 0, bottom: 14, right: 0)
    }

    override func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedRendering {
            let width = availableWidth - indent
            let height = (width / embedWidth) * embedHeight
            contentsFrame = NSRect(x: indent, y: 0, width: width, height: childInset + height + elementNodePadding.bottom + elementNodePadding.top)

            if let embedLayer = layers["embed"] {
                embedLayer.layer.position = CGPoint(x: indent, y: 0)
                embedLayer.layer.bounds = CGRect(origin: embedLayer.frame.origin, size: CGSize(width: width - indent, height: contentsFrame.height - elementNodePadding.bottom - elementNodePadding.top))
                updateFocus()
            }

            invalidatedRendering = false
        }

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width

        if open && selfVisible {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    override func updateLayersVisibility() {
        super.updateLayersVisibility()
        webView?.isHidden = layer.isHidden
    }

    override func updateChildrenLayout() {
        let r = layer.frame
        webView?.frame = NSRect(x: r.minX + indent, y: r.minY + elementNodePadding.top, width: r.width - indent, height: r.height - elementNodePadding.bottom - elementNodePadding.top )
        super.updateChildrenLayout()
    }

    var focusMargin = CGFloat(3)
    public override func updateElementCursor() {
        let on = editor.hasFocus && isFocused && editor.blinkPhase && (root?.state.nodeSelection?.nodes.isEmpty ?? true)
        let cursorRect = NSRect(x: caretIndex == 0 ? (indent - 5) : (contentsFrame.width + 3), y: elementNodePadding.top - focusMargin, width: 2, height: layer.frame.height - elementNodePadding.bottom - elementNodePadding.top + focusMargin * 2)
        let layer = self.cursorLayer

        layer.shapeLayer.fillColor = enabled ? cursorColor.cgColor : disabledColor.cgColor
        layer.layer.isHidden = !on
        layer.shapeLayer.path = CGPath(rect: cursorRect, transform: nil)
    }

    override func updateFocus() {
        guard let embedLayer = layers["embed"] else { return }

        embedLayer.layer.sublayers?.forEach { l in
            l.removeFromSuperlayer()
        }
        guard isFocused else {
            embedLayer.layer.mask = nil
            return
        }
        let bounds = embedLayer.bounds.insetBy(dx: -focusMargin, dy: -focusMargin)
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
        borderLayer.position = CGPoint(x: indent + childInset + embedLayer.layer.bounds.width / 2, y: embedLayer.layer.bounds.height / 2 + elementNodePadding.top)
        borderLayer.mask = mask
        embedLayer.layer.addSublayer(borderLayer)
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
        guard let note = root?.editor.note as? BeamNote,
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
