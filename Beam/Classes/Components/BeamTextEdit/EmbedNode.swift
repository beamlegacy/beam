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

public class EmbedNode: ElementNode {
    var webView = WKWebView()

    override init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element)

        setupEmbed()

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)
    }

    override init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element)

        setupEmbed()

        setAccessibilityLabel("EmbedNode")
        setAccessibilityRole(.textArea)
    }

    func setupEmbed() {
        var source = ""
        switch element.kind {
        case .embed(let sourceURL):
            source = sourceURL
        default:
            Logger.shared.logError("EmbedNode can only handle url elements, not \(element.kind)", category: .noteEditor)
            return
        }

        // Setup URL in WkWebView

//        let width = availableWidth - childInset
//        let height = (width / image.size.width) * image.size.height
//        let imageLayer = Layer.image(named: "image", image: image, size: CGSize(width: width, height: height))
//        imageLayer.layer.position = CGPoint(x: indent, y: 0)
//        addLayer(imageLayer, origin: CGPoint(x: indent, y: 0))

        webView = BeamWebView(frame: NSRect(), configuration: BrowserTab.webViewConfiguration)
        webView.wantsLayer = true
        webView.allowsMagnification = true
        editor.addSubview(webView)

        guard let url = URL(string: source)?.embed
        else { return }
        AppDelegate.main.data.setup(webView: webView)
        webView.load(URLRequest(url: url))

        layer.zPosition = -1
    }

    deinit {
        webView.removeFromSuperview()
    }

    let embedWidth = CGFloat(320)
    let embedHeight = CGFloat(240)

    override func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedRendering {
            let width = availableWidth - indent
            let height = (width / embedWidth) * embedHeight
            contentsFrame = NSRect(x: indent, y: 0, width: width, height: childInset + height)

//            if let imageLayer = layers["image"] {
//                imageLayer.layer.position = CGPoint(x: indent + childInset, y: 0)
//                imageLayer.layer.bounds = CGRect(origin: imageLayer.frame.origin, size: CGSize(width: width, height: height))
//
                updateFocus()
//            }

            computedIdealSize = contentsFrame.size
            computedIdealSize.width = frame.width

            invalidatedRendering = false
        }

        if open && selfVisible {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    override func updateChildrenLayout() {
        let r = layer.frame
        webView.frame = NSRect(x: r.minX + indent, y: r.minY, width: r.width - indent, height: r.height)
        webView.isHidden = layer.isHidden

        super.updateChildrenLayout()
    }
    func updateFocus() {
        guard let imageLayer = layers["image"] else { return }

        imageLayer.layer.sublayers?.forEach { l in
            l.removeFromSuperlayer()
        }
        guard isFocused else {
            imageLayer.layer.mask = nil
            return
        }
        let bounds = imageLayer.bounds.insetBy(dx: -3, dy: -3)
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
        borderLayer.position = CGPoint(x: indent + childInset + imageLayer.layer.bounds.width / 2, y: imageLayer.layer.bounds.height / 2)
        borderLayer.mask = mask
        imageLayer.layer.addSublayer(borderLayer)
    }

    override func onUnfocus() {
        updateFocus()
    }
    override func onFocus() {
        updateFocus()
    }

    // WKNavigationDelegate:
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .noteEditor)
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationAction))", category: .noteEditor)
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        Logger.shared.logDebug("Embed decidePolicyFor: \(String(describing: navigationResponse))", category: .noteEditor)
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didStartProvisionalNavigation: \(String(describing: navigation))", category: .noteEditor)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didReceiveServerRedirectForProvisionalNavigation: \(String(describing: navigation))", category: .noteEditor)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logDebug("Embed didFailProvisionalNavigation: \(String(describing: navigation))", category: .noteEditor)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didCommit: \(String(describing: navigation))", category: .noteEditor)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.shared.logDebug("Embed didFinish: \(String(describing: navigation))", category: .noteEditor)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.logError("Embed Error: \(error)", category: .noteEditor)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {

    }

    func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(true)
    }

}
