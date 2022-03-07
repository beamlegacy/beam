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
    let controller: TransientWebViewController

    private var scope = Set<AnyCancellable>()

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

        self.setFrameAutosaveName("Beam")
        self.isReleasedWhenClosed = false
        self.contentView = self.controller.webView
        self.controller.webView.publisher(for: \.title)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [unowned self] newTitle in
                self.title = newTitle ?? "Beam"
            }.store(in: &scope)
    }

}

class TransientWebViewController: BaseWebNavigationController {

    let uiDelegateController = TransientWebViewUIDelegateController()
    let webView: BeamWebView
    var url: URL?

    /// Creates a basic temporary WebView window.
    /// - Parameters:
    ///   - originPage: The WebPage that spawed this transient webview. Since we don't want to keep the TransientWebView around for long any tabs or windows created by this webview should not be created in the TransientWebView but instead be created from the originPage.
    ///   - configuration: WebView Configuration.
    ///   - contentRect: Size of the webview to be created.
    init(originPage: WebPage?, configuration: WKWebViewConfiguration?, contentRect: NSRect) {
        self.webView = BeamWebView(frame: contentRect, configuration: configuration ?? WKWebViewConfiguration())
        self.webView.enableAutoCloseWindow = true
        self.webView.wantsLayer = true
        self.webView.allowsMagnification = true
        super.init()
        self.page = originPage
        uiDelegateController.page = originPage
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = uiDelegateController
    }

}

class TransientWebViewUIDelegateController: BeamWebkitUIDelegateController {
    override func webViewDidClose(_ webView: WKWebView) {
        webView.window?.close()
    }
}
