//
//  TransientWebViewWindow.swift
//  Beam
//
//  Created by Stef Kors on 24/02/2022.
//

import Foundation
import BeamCore
import Combine

class TransientWebViewWindow: NSWindow, NSWindowDelegate {
    private let controller: TransientWebViewController

    var webView: BeamWebView {
        controller.wv
    }

    init(originPage: WebPage?, configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures? = nil) {
        let contentRect: CGRect = windowFeatures?.toRect() ?? .zero
        self.controller = .init(originPage: originPage, configuration: configuration, contentRect: contentRect)

        var styleMask: StyleMask = [.closable, .miniaturizable, .titled, .unifiedTitleAndToolbar]
        if windowFeatures?.allowsResizing != 0 {
            styleMask.insert(NSWindow.StyleMask.resizable)
        }
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        title = "Beam"

        self.setFrameAutosaveName("BeamTransientWebViewWindow")
        self.isReleasedWhenClosed = false
        self.contentView = self.controller.wv
        self.controller.delegate = self
    }
}

extension TransientWebViewWindow: WebViewControllerDelegate {
    func webViewController<Value>(_ controller: WebViewController, observedValueChangedFor keyPath: KeyPath<WKWebView, Value>, value: Value) {
        guard keyPath == \.title, let title = value as? String else {
            return
        }
        self.title = title
    }

    func webViewController(_ controller: WebViewController, didChangeDisplayURL url: URL) { }
    func webViewController(_ controller: WebViewController, willMoveInHistory forward: Bool) { }
    func webViewControllerIsNavigatingToANewPage(_ controller: WebViewController) { }
    func webViewController(_ controller: WebViewController, didFinishNavigatingToPage navigationDescription: WebViewNavigationDescription) { }
    func webViewController(_ controller: WebViewController, didChangeLoadedContentType contentDescription: BrowserContentDescription?) { }
}

private class TransientWebViewController: WebViewController {

    private let uiDelegateController = TransientWebViewUIDelegateController()
    fileprivate let wv: BeamWebView

    override var page: WebPage? {
        // Don't setup the page to avoid the transient webview to trigger changes in the tab itself
        // Ideally the WebViewController wouldn't need a page anyway. so to be removed soonish.
        get { nil }
        set {
            _ = newValue
            fatalError("Don't set page property on the TransientWebViewController")
        }
    }
    /// Creates a basic temporary WebView window.
    /// - Parameters:
    ///   - originPage: The WebPage that spawed this transient webview. Since we don't want to keep the TransientWebView around for long any tabs or windows created by this webview should not be created in the TransientWebView but instead be created from the originPage.
    ///   - configuration: WebView Configuration.
    ///   - contentRect: Size of the webview to be created.
    init(originPage: WebPage?, configuration: WKWebViewConfiguration?, contentRect: NSRect) {
        let webView = BeamWebView(frame: contentRect, configuration: configuration ?? WKWebViewConfiguration())
        webView.enableAutoCloseWindow = true
        webView.wantsLayer = true
        webView.allowsMagnification = true
        wv = webView
        super.init(with: webView)
        uiDelegateController.page = originPage
        webkitNavigationHandler.page = originPage
        webView.uiDelegate = uiDelegateController
    }

}

private class TransientWebViewUIDelegateController: BeamWebkitUIDelegateController {
    override func webViewDidClose(_ webView: WKWebView) {
        webView.window?.close()
    }
}
